import { LightningElement, api, track, wire } from 'lwc';
import logo from '@salesforce/resourceUrl/Logo';
import MobileChatModal from 'c/mobileChatModal';
import ContactFinanceForm from 'c/contactFinanceForm';

import createThread from '@salesforce/apex/OpenAIAssistantService.createThread';
import sendMessageAndRun from '@salesforce/apex/OpenAIAssistantService.sendMessageAndRun';
import pollRunStatus from '@salesforce/apex/OpenAIAssistantService.pollRunStatus';
import getAssistantMessages from '@salesforce/apex/OpenAIAssistantService.getAssistantMessages';
import createFutureErrorRecord from '@salesforce/apex/Utility.createFutureErrorRecord';
import getWidgetForMatter from '@salesforce/apex/TSFinanceWidgetController.getWidgetForMatter';
import getCIFormStatus from '@salesforce/apex/TaskController.getCIFormStatus';
import getRecentActivities from '@salesforce/apex/PortalActivityController.getRecentActivities';

const RECENT_UPDATES_LIMIT = 4;
const CHAT_MAX_POLLS = 30; // ~30s at a 1s interval before we give up on a run

// Fee-agreement signing statuses that mean the agreement is NOT yet in a
// "ready to proceed" state. Mirrors the virtualAccountCreater cascade (~ll. 357–368).
const FA_BLOCKING_STATUSES = ['Out for Signature', 'Cancelled', 'Expired'];
const GOLD_ZERO_RETAINER = 'Gold - 0% Retainer';

// CI form ordering — duplicated from virtualAccountCreater.js (line ~29).
// TODO: factor into a shared util once a second consumer needs it.
const CI_FORM_ORDER = [
    'Vitals', 'Contact', 'Identity', 'Marriage', 'Education', 'Military',
    'Current Family', 'Social Media',
    'Opposing Party', 'OP-Contact', 'OP-Identity', 'OP-Family', 'OP-Education',
    'OP-Military', 'OP-Social Media', 'OP-Service of Process',
    'Children', 'Children With OP', 'Children from a Different Relationship',
    'Assets', 'Vehicles', 'Real Property', 'Bank Accounts', 'Investment Accounts',
    'Retirement Accounts', 'Life Insurance', 'Furniture/Personal Property', 'Additional',
    'Debts', 'Credit Cards', 'Additional Debts',
    'Income', 'Expenses', 'Additional Uploads'
];

export default class UserDashboard extends LightningElement {

    // ── Parent-supplied data (passed via attribute binding) ─────────
    _matters;
    _account;
    _hasLoaded = false;

    @api
    get matters() { return this._matters; }
    set matters(value) {
        this._matters = value;
        this.tryLoad();
    }

    @api
    get account() { return this._account; }
    set account(value) {
        this._account = value;
        this.tryLoad();
    }

    // ── State ───────────────────────────────────────────────────────
    @track currentMatterIndex = 0;
    @track viewMatters = [];
    @track isLoading = true;
    @track loadError = null;

    // Recent Updates — sourced from Salesforce Activity (Task records) via
    // PortalActivityController. Filter rule provisional pending Skylar's
    // final answer on which Task types are client-facing.
    @track recentUpdates = [];

    @wire(getRecentActivities, { limitN: RECENT_UPDATES_LIMIT })
    wiredRecentUpdates({ data, error }) {
        if (data) {
            this.recentUpdates = data;
        } else if (error) {
            // Soft-fail — the strip just goes empty, nothing else breaks.
            this.recentUpdates = [];
            this.logError(error, 'userDashboard.getRecentActivities');
        }
    }

    get hasRecentUpdates() {
        return this.recentUpdates && this.recentUpdates.length > 0;
    }

    // TODO: real FAQ source TBD — placeholder until Skylar confirms.
    // Answers are lorem-style placeholders for now.
    faqItems = [
        {
            id: 'faq-1',
            question: 'How do I make a payment?',
            answer: 'Open the matter you want to pay from your dashboard and choose “Pay now” in the Billing Summary. You’ll be taken to a secure payment page to complete your retainer or invoice.'
        },
        {
            id: 'faq-3',
            question: 'How do I upload documents?',
            answer: 'From your matter’s next step, select “Continue” and follow the prompts to the document section. You can drag and drop files or browse from your device.'
        }
    ];

    // Id of the currently expanded FAQ (single-open accordion). Null = all closed.
    @track openFaqId = null;

    // Display model: each item plus its open state and the chevron direction.
    get faqDisplay() {
        return this.faqItems.map(item => {
            const isOpen = item.id === this.openFaqId;
            return {
                ...item,
                isOpen,
                itemClass: isOpen ? 'faq-item faq-item_open' : 'faq-item',
                iconName: isOpen ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    // ── Data load ───────────────────────────────────────────────────
    tryLoad() {
        // Both @api props must arrive before we can fetch per-matter data.
        if (this._hasLoaded) return;
        if (!this._matters || !this._account) return;
        this._hasLoaded = true;
        this.loadDashboardData();
    }

    loadDashboardData() {
        this.isLoading = true;
        this.loadError = null;

        const matters = this._matters || [];
        if (matters.length === 0) {
            // Parent gates showUserDashboard on length >= 1, so this shouldn't
            // happen — but fail soft.
            this.viewMatters = [];
            this.isLoading = false;
            return;
        }

        // For each matter, fetch the billing widget + CI form status in parallel.
        // Use allSettled so one matter's failure doesn't kill the whole dashboard.
        const perMatterPromises = matters.map(m =>
            Promise.allSettled([
                getWidgetForMatter({ matterId: m.Id }),
                getCIFormStatus({ matterId: m.Id })
            ])
        );

        Promise.all(perMatterPromises)
            .then(results => {
                this.viewMatters = matters.map((rawMatter, idx) => {
                    const [widgetResult, ciResult] = results[idx];
                    const widget = widgetResult.status === 'fulfilled' ? widgetResult.value : null;
                    const ciForms = ciResult.status === 'fulfilled' ? (ciResult.value || []) : [];

                    if (widgetResult.status === 'rejected') {
                        this.logError(widgetResult.reason, 'userDashboard.getWidgetForMatter');
                    }
                    if (ciResult.status === 'rejected') {
                        this.logError(ciResult.reason, 'userDashboard.getCIFormStatus');
                    }

                    return this.shapeMatter(rawMatter, widget, ciForms, idx, matters.length);
                });
                this.currentMatterIndex = 0;
                this.isLoading = false;
            })
            .catch(error => {
                this.loadError = error.message || 'Failed to load dashboard data.';
                this.isLoading = false;
                this.logError(error, 'userDashboard.loadDashboardData');
            });
    }

    handleRetry() {
        this._hasLoaded = false;
        this.tryLoad();
    }

    // Build the view model the existing template binds against.
    shapeMatter(raw, widget, ciForms, index, total) {
        const attorneyName = raw.Primary_Attorney__r?.Name || '';
        const paralegalName = raw.Primary_Paralegal__r?.Name || '';
        const nextStep = this.deriveNextStep(raw, this._account, ciForms, widget);
        const totalBalanceRaw = widget?.Timesolv_Trust_Balance__c ?? 0;
		const openWithDates = (ciForms || [])
		.filter(t => t.Status === 'Open' && t.ActivityDate)
		.map(t => t.ActivityDate)
		.sort();
		const ciDueDate = openWithDates.length ? openWithDates[0] : '';

        return {
            id: raw.Id,
            matterNumber: index + 1,
            totalMatters: total,
            title: raw.Case_Type__c || 'Matter',
            caseType: raw.Case_Type__c || '—',
            status: raw.Status__c || '—',
            lastUpdated: this.formatDate(raw.LastModifiedDate),
            // TODO: no court-date / due-date fields on Matters__c yet (asked Don)
            nextCourtDate: '',
            dueDate: ciDueDate ? this.formatDate(ciDueDate) : '',
            attorney: { name: attorneyName, initials: this.initials(attorneyName) },
            paralegal: { name: paralegalName, initials: this.initials(paralegalName) },
            totalBalanceRaw,
            totalBalance: this.formatCurrency(totalBalanceRaw),
            // TODO: confirm billing due-date field with Don
            billingDueDate: '',
            nextStep,
            badge: nextStep.badge,
            badgeClass: nextStep.badgeClass
        };
    }

    // ── Next-step derivation ────────────────────────────────────────
    // Pure function. Precedence:
    //   1 attorney transition → 2 CI in progress (open forms) →
    //   3 generate fee agreement → 4 awaiting retainer payment →
    //   5 continue/start client interview → 6 billing overdue → 7 up to date
    // States 3–5 implement Skylar's spec (2026-05-29). Field names, picklist
    // values and AND/OR grouping mirror the virtualAccountCreater cascade
    // (~lines 352–368), which is the canonical implementation of that logic.
    // CTA strings are placeholders — Skylar will define the final copy.
    deriveNextStep(matter, account, ciForms, widget) {
        const acct = account || {};

        // 1. Attorney transition (matches the parent's cascade gate)
        const attorney = matter?.Primary_Attorney__r;
        const needsTransition = !matter?.Retaining_Client_Date__c
            && attorney
            && (attorney.Retaining_Clients__c === true || attorney.Not_Retaining_Clients__c === true);
        if (needsTransition) {
            return {
                type: 'attorneyTransition',
                title: 'Attorney transition decision',
                description: 'Please confirm whether you want to continue with your assigned attorney.',
                badge: 'Action Needed',
                badgeClass: 'badge badge-amber',
                ctaLabel: 'Continue', // CTA-TBD-Skylar
                showContinue: true
            };
        }

        // 2. Client Interview in progress — open CI form tasks exist.
        // Checked before the fee-agreement states below because CI Form tasks
        // are only created post-payment (CI_Process_* flows), so their presence
        // reliably means the client is already past the FA / retainer phase.
        const openForms = (ciForms || []).filter(t => t.Status === 'Open');
        if (openForms.length > 0) {
            const firstOpen = openForms
                .slice()
                .sort((a, b) => {
                    const ai = CI_FORM_ORDER.indexOf(a.ci_form__c || a.Subject);
                    const bi = CI_FORM_ORDER.indexOf(b.ci_form__c || b.Subject);
                    return (ai === -1 ? 999 : ai) - (bi === -1 ? 999 : bi);
                })[0];
            const formName = firstOpen.ci_form__c || firstOpen.Subject || 'your client interview';
            return {
                type: 'clientInterview',
                title: 'Continue Client Interview',
                description: `Continue with: ${formName}`,
                badge: 'In Progress',
                badgeClass: 'badge badge-blue',
                ctaLabel: 'Continue', // CTA-TBD-Skylar
                showContinue: true
            };
        }

        // ── Fee-agreement → retainer → client-interview states (Skylar) ──
        const signingUrl = acct.Fa_Portal_Signing_URL__c;
        const agreementStatus = acct.FA_Portal_Agreement_Status__c;
        const creditDecision = acct.Credit_Decision__c;
        const trustBalance = acct.Timesolv_TrustAccount_Balance__c;
        const feeAmount = acct.Total_Fee_Agreement_Amount__c;
        // Agreement is in a "ready to proceed" state (signed — not pending/void).
        const faStatusReady = agreementStatus !== undefined
            && !FA_BLOCKING_STATUSES.includes(agreementStatus);

        // 3. Generate your Fee Agreement — no signing URL generated yet.
        // Gated on Allow_Fee_Agreement__c (the parent's `sendFeeAgreement`) so
        // it only fires for clients actually in the fee-agreement lifecycle,
        // not every established client whose URL happens to be blank.
        if (acct.Allow_Fee_Agreement__c === true && !signingUrl) {
            return {
                type: 'feeAgreement',
                title: 'Generate your Fee Agreement',
                description: 'Start your fee agreement to move your matter forward.',
                badge: 'Action Needed',
                badgeClass: 'badge badge-amber',
                ctaLabel: 'Continue', // CTA-TBD-Skylar
                showContinue: true
            };
        }

        // 4. Awaiting retainer payment — agreement signed but retainer not yet
        // paid, and not a Gold 0% retainer (who owe nothing). The trust-balance
        // clause mirrors the parent cascade (~line 362).
        if (signingUrl
            && faStatusReady
            && creditDecision !== GOLD_ZERO_RETAINER
            && (trustBalance === undefined || trustBalance !== feeAmount)) {
            return {
                type: 'payInvoice',
                title: 'Awaiting retainer payment',
                description: 'Please pay your retainer to continue.',
                badge: 'Action Needed',
                badgeClass: 'badge badge-amber',
                ctaLabel: 'Pay now', // CTA-TBD-Skylar
                showContinue: true
            };
        }

        // 5. Continue your client interview — retainer covered (paid, or Gold
        // 0%) and the agreement is ready, but no CI forms enrolled yet (none
        // returned). If forms exist they're handled by state 2 (open) or fall
        // through to "up to date" (all complete).
        const retainerCovered = creditDecision === GOLD_ZERO_RETAINER
            || (feeAmount !== undefined && trustBalance === feeAmount);
        if (retainerCovered && faStatusReady && (ciForms || []).length === 0) {
            return {
                type: 'clientInterview',
                title: 'Continue your client interview',
                description: 'Your retainer is set — continue your client interview.',
                badge: 'In Progress',
                badgeClass: 'badge badge-blue',
                ctaLabel: 'Continue', // CTA-TBD-Skylar
                showContinue: true
            };
        }

        // 6. Billing overdue (provisional rule — confirm with Don)
        if (widget && typeof widget.Timesolv_Trust_Balance__c === 'number'
            && widget.Timesolv_Trust_Balance__c < 0) {
            return {
                type: 'payInvoice',
                title: 'Outstanding balance',
                description: 'Please pay your invoice to keep your matter moving.',
                badge: 'Overdue',
                badgeClass: 'badge badge-red',
                ctaLabel: 'Pay now', // CTA-TBD-Skylar
                showContinue: true
            };
        }

        // 7. Default — nothing to do
        return {
            type: 'upToDate',
            title: 'You’re all caught up',
            description: 'No action needed right now.',
            badge: 'Active',
            badgeClass: 'badge badge-green',
            ctaLabel: '',
            showContinue: false
        };
    }

    // ── Small helpers ───────────────────────────────────────────────
    initials(name) {
        if (!name) return '';
        return name
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map(s => s[0].toUpperCase())
            .join('');
    }

    formatCurrency(n) {
        if (n == null || isNaN(n)) return '$0.00';
        return n.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
    }

    formatDate(value) {
        if (!value) return '';
        const d = new Date(value);
        if (isNaN(d.getTime())) return '';
        return `${d.getMonth() + 1}/${d.getDate()}/${String(d.getFullYear()).slice(-2)}`;
    }

    // ── Header / branding ───────────────────────────────────────────
    logoUrl = logo;
    get userName() {
        const acc = this._account;
        if (!acc) return '';
        // Try the common Salesforce field shapes (case-sensitive). Falls back
        // to the first word of Name, then empty.
        return acc.FirstName
            || acc.firstName
            || (acc.Name ? acc.Name.split(/\s+/)[0] : '')
            || '';
    }

    // Used in the header so we don't render "Welcome back, " with an empty trail
    // before the account loads. Reads cleanly whether or not we have a name.
    get welcomeGreeting() {
        const name = this.userName;
        return name ? `Welcome back, ${name}` : 'Welcome back';
    }

    // ── Getters for current matter (template bindings unchanged) ────
    get currentMatter() { return this.viewMatters[this.currentMatterIndex]; }
    get hasMatters() { return this.viewMatters.length > 0; }
    get matterTitle() {
        const m = this.currentMatter;
        if (!m) return '';
        return `Matter ${m.matterNumber} of ${this.viewMatters.length} — ${m.title}`;
    }
    get matterBadge() { return this.currentMatter?.badge || ''; }
    get badgeClass() { return this.currentMatter?.badgeClass || 'badge'; }
    get nextStepTitle() { return this.currentMatter?.nextStep?.title || ''; }
    get nextStepDesc() { return this.currentMatter?.nextStep?.description || ''; }
    get showContinueButton() { return this.currentMatter?.nextStep?.showContinue !== false; }
    get caseStatus() { return this.currentMatter?.status || ''; }
    get caseType() { return this.currentMatter?.caseType || ''; }
    get lastUpdated() { return this.currentMatter?.lastUpdated || ''; }
    get nextCourtDate() { return this.currentMatter?.nextCourtDate || ''; }
    get dueDate() { return this.currentMatter?.dueDate || ''; }
    get attorney() { return this.currentMatter?.attorney || { name: '', initials: '' }; }
    get paralegal() { return this.currentMatter?.paralegal || { name: '', initials: '' }; }
    get totalBalance() { return this.currentMatter?.totalBalance || '$0.00'; }
    get billingDueDate() { return this.currentMatter?.billingDueDate || ''; }
    get isPrevDisabled() { return this.currentMatterIndex === 0; }
    get isNextDisabled() { return this.currentMatterIndex >= this.viewMatters.length - 1; }
    get totalMatters() { return this.viewMatters.length; }

    // ── Navigation ──────────────────────────────────────────────────
    handlePrevMatter() {
        if (this.currentMatterIndex > 0) this.currentMatterIndex--;
    }

    handleNextMatter() {
        if (this.currentMatterIndex < this.viewMatters.length - 1) this.currentMatterIndex++;
    }

    handleViewAllMatters() {
        this.dispatchEvent(new CustomEvent('viewallmatters', { bubbles: true, composed: true }));
    }

    // ── Action handlers (bubble up to parent) ───────────────────────
    handleContinue() {
        const m = this.currentMatter;
        if (!m) return;
        this.dispatchEvent(new CustomEvent('continuestep', {
            detail: { matterId: m.id, stepType: m.nextStep?.type },
            bubbles: true, composed: true
        }));
    }

    handleMessageTeam() {
        this.dispatchEvent(new CustomEvent('messageteam', {
            detail: { matterId: this.currentMatter?.id },
            bubbles: true, composed: true
        }));
    }

    handlePayNow() {
        const m = this.currentMatter;
        if (!m) return;
        this.dispatchEvent(new CustomEvent('paynow', {
            detail: { matterId: m.id, amount: m.totalBalanceRaw },
            bubbles: true, composed: true
        }));
    }

    // Opens the Contact Finance modal directly (LightningModal pattern, same
    // as mobileChatModal). Passes the account + matters so the form can
    // pre-fill name/email and offer a matter dropdown.
    handleContactFinance() {
        ContactFinanceForm.open({
            size: 'small',
            label: 'Contact Finance',
            account: this._account,
            matters: this._matters
        }).then(result => {
            // result === 'sent' on success, 'cancel' on dismiss
            if (result === 'sent') {
                // Lightweight confirmation — toast event bubbles to the parent
                // which can show a ShowToastEvent. Kept as an event so the
                // dashboard doesn't need to import the toast utility itself.
                this.dispatchEvent(new CustomEvent('financesent', {
                    bubbles: true, composed: true
                }));
            }
        });
    }

    // Toggle the accordion item open/closed (single-open behaviour).
    handleFaqToggle(event) {
        const faqId = event.currentTarget.dataset.id;
        this.openFaqId = (this.openFaqId === faqId) ? null : faqId;
    }

    handleViewAllFaqs() {
        this.dispatchEvent(new CustomEvent('viewallfaqs', { bubbles: true, composed: true }));
    }

    handleViewAllUpdates() {
        this.dispatchEvent(new CustomEvent('viewallupdates', { bubbles: true, composed: true }));
    }

    // Footer legal-links — currently a stub so the spawn meeting can confirm
    // whether these route to standalone pages, modals, or external URLs.
    // TODO: wire real destinations once Skylar/Don decide.
    handleFooterLink(event) {
        const key = event.currentTarget?.dataset?.key;
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('footerlink', {
            detail: { key },
            bubbles: true, composed: true
        }));
    }

    // Mobile-only floating chat button — opens the existing mobileChatModal
    // (same component virtualAccountCreater uses for its mobile chat).
    openMobileChat() {
        MobileChatModal.open({ size: 'large', label: 'How can I help?' });
    }

    // Bubbles up to the parent, which calls NavigationMixin → community logout.
    // Kept as an event (vs. doing the navigation here) so logout policy stays
    // centralised on virtualAccountCreater.
    handleLogout() {
        this.dispatchEvent(new CustomEvent('logout', { bubbles: true, composed: true }));
    }

    // ── Lifecycle ───────────────────────────────────────────────────
    disconnectedCallback() {
        // Clear any in-flight dots-animation intervals attached to thinking
        // indicators. Without this, the interval keeps firing forever if the
        // user navigates away mid-chat (since setInterval is tied to the
        // global timer table, not the LWC instance).
        const indicators = this.template?.querySelectorAll?.('.thinking');
        if (indicators) {
            indicators.forEach(el => {
                const id = el.dataset?.intervalId;
                if (id) clearInterval(parseInt(id, 10));
            });
        }
    }

    connectedCallback() {
        // Chat init runs regardless of dashboard data state.
        createThread()
            .then(result => {
                const data = JSON.parse(result);
                this.threadId = data.id;
                this.appendMessage(
                    'Welcome to Modern Family Law!<br><br>I am an AI chatbot that can help answer any questions you have as you go through your onboarding activities. Let me know if you need any assistance.',
                    'bot',
                    true
                );
            })
            .catch(error => this.logError(error, 'userDashboard.createThread'));

        // If both @api props happened to arrive before connectedCallback, kick load.
        this.tryLoad();
    }

    // ── Chatbot state ───────────────────────────────────────────────
    threadId;
    userMessage = '';
    isThinking = false;

    handleInput(event) {
        this.userMessage = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSendMessage();
        }
    }

    handleSendMessage() {
        if (this.isThinking) return;

        const trimmed = this.userMessage.trim();
        if (!trimmed) return;

        this.appendMessage(trimmed, 'user');
        const messageToSend = trimmed;
        this.userMessage = '';

        this.isThinking = true;
        const thinkingId = this.appendThinkingIndicator();

        const processRun = (runResult) => {
            const data = JSON.parse(runResult);
            this.pollStatus(this.threadId, data.id, thinkingId);
        };

        if (!this.threadId) {
            createThread()
                .then(result => {
                    const data = JSON.parse(result);
                    this.threadId = data.id;
                    return sendMessageAndRun({ threadId: this.threadId, userMessage: messageToSend });
                })
                .then(processRun)
                .catch(error => {
                    this.removeThinkingIndicator(thinkingId);
                    this.isThinking = false;
                    this.logError(error, 'userDashboard.handleSendMessage.createThread');
                });
        } else {
            sendMessageAndRun({ threadId: this.threadId, userMessage: messageToSend })
                .then(processRun)
                .catch(error => {
                    this.removeThinkingIndicator(thinkingId);
                    this.isThinking = false;
                    this.logError(error, 'userDashboard.sendMessageAndRun');
                });
        }
    }

    appendMessage(text, sender, isHtml = false) {
        const container = this.template.querySelector('.messages-container');
        const scrollWrapper = this.template.querySelector('.chat-box');

        if (container) {
            const el = document.createElement('div');
            el.classList.add('message', sender);
            if (isHtml) {
                el.innerHTML = text;
            } else {
                el.textContent = text;
            }
            container.appendChild(el);
            if (scrollWrapper) {
                scrollWrapper.scrollTop = scrollWrapper.scrollHeight;
            }
        } else {
            console.error('.messages-container not found');
        }
    }

    appendThinkingIndicator() {
        const container = this.template.querySelector('.messages-container');
        const el = document.createElement('div');
        el.classList.add('message', 'bot', 'thinking');
        el.innerHTML = '<em>Thinking<span class="dots">...</span></em>';
        const id = `thinking-${Date.now()}`;
        el.id = id;
        container.appendChild(el);
        container.scrollTop = container.scrollHeight;

        const dots = el.querySelector('.dots');
        let dotCount = 3;
        const interval = setInterval(() => {
            dots.textContent = '.'.repeat(dotCount);
            dotCount = (dotCount % 6) + 1;
        }, 500);

        el.dataset.intervalId = interval;
        return id;
    }

    removeThinkingIndicator(id) {
        const el = this.template.querySelector(`#${id}`);
        if (el) {
            const intervalId = el.dataset.intervalId;
            if (intervalId) clearInterval(parseInt(intervalId, 10));
            el.remove();
        }
    }

    pollStatus(threadId, runId, thinkingId, attempt = 0) {
        // Cap polling so a stuck/never-completing OpenAI run can't leave the
        // user staring at "Thinking…" forever. 1s interval × 30 ≈ 30s.
        if (attempt >= CHAT_MAX_POLLS) {
            this.removeThinkingIndicator(thinkingId);
            this.isThinking = false;
            this.appendMessage(
                'Sorry — I’m having trouble responding right now. Please try again in a moment.',
                'bot'
            );
            console.warn('Chat run timed out after', CHAT_MAX_POLLS, 'polls');
            return;
        }
        pollRunStatus({ threadId, runId })
            .then(result => {
                const data = JSON.parse(result);
                const status = data.status;

                if (status === 'completed') {
                    this.fetchAssistantReply(threadId, thinkingId);
                } else if (['queued', 'in_progress'].includes(status)) {
                    setTimeout(() => this.pollStatus(threadId, runId, thinkingId, attempt + 1), 1000);
                } else {
                    // failed / cancelled / expired / requires_action
                    this.removeThinkingIndicator(thinkingId);
                    this.isThinking = false;
                    this.appendMessage(
                        'Sorry — I couldn’t complete that request. Please try again.',
                        'bot'
                    );
                    console.warn('Run failed or cancelled:', status);
                }
            })
            .catch(error => {
                this.removeThinkingIndicator(thinkingId);
                this.isThinking = false;
                this.logError(error, 'userDashboard.pollStatus');
            });
    }

    fetchAssistantReply(threadId, thinkingId) {
        getAssistantMessages({ threadId })
            .then(result => {
                const data = JSON.parse(result);
                const assistantMessages = data.data.filter(msg => msg.role === 'assistant');
                if (assistantMessages.length > 0) {
                    const lastMessage = assistantMessages[0];
                    let messageText = '';

                    for (const part of lastMessage.content) {
                        if (part.type === 'text') {
                            messageText += part.text.value;
                        }
                    }

                    this.removeThinkingIndicator(thinkingId);
                    this.isThinking = false;
                    this.appendMessage(this.formatBotReply(messageText), 'bot', true);
                } else {
                    this.removeThinkingIndicator(thinkingId);
                    this.isThinking = false;
                }
            })
            .catch(error => {
                this.removeThinkingIndicator(thinkingId);
                this.isThinking = false;
                this.logError(error, 'userDashboard.fetchAssistantReply');
            });
    }

    formatBotReply(reply) {
        let formatted = reply
            .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
            .replace(/\n/g, '<br>');

        const listItemRegex = /<br>(\s*[-*•]\s+|\s*\d+\.\s+)(.+?)(?=<br>|$)/g;
        formatted = formatted.replace(listItemRegex, (match, bullet, content) => {
            return '<br><li>' + content + '</li>';
        });
        formatted = formatted.replace(/(<li>.+?<\/li>)(\s*<br>\s*<li>.+?<\/li>)*/g, '<ul>$&</ul>');
        return formatted;
    }

    // ── Shared error logger ─────────────────────────────────────────
    logError(error, procname) {
        const exceptionMessage = error?.message ?? error?.body?.message ?? String(error);
        const stackTrace = error?.stack ?? error?.body?.stackTrace ?? '';
        createFutureErrorRecord({
            exceptionMessage,
            stackTrace,
            lineNum: 0,
            errortype: 'Javascript',
            procname
        }).catch(err => console.error('Failed to log error:', err));
        console.error('Exception thrown:', error, 'stack trace:', stackTrace);
    }
}