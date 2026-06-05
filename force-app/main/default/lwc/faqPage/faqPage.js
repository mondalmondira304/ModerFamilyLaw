import { LightningElement } from 'lwc';

// TODO: replace with real content from Custom Metadata (FAQ_Item__mdt) once
// Skylar confirms the source. Lorem-ipsum placeholders OK for demo.
const PLACEHOLDER_FAQS = [
    {
        id: 'faq-1',
        question: 'How do I make a payment?',
        answer: 'You can make a payment through the secure payment link sent with your fee agreement, or by clicking "Pay now" from your dashboard. We accept all major credit cards and ACH transfers.'
    },
    {
        id: 'faq-2',
        question: 'How do I upload documents?',
        answer: 'Within each matter, you\'ll find an "Additional Uploads" section in your client interview. Drag and drop files there, or click to browse. We accept PDF, JPG, PNG, and most document formats.'
    },
    {
        id: 'faq-3',
        question: 'How do I message my legal team?',
        answer: 'Use the "Message team" button on your matter card to send a secure message to your attorney and paralegal. They typically respond within one business day.'
    },
    {
        id: 'faq-4',
        question: 'What if I need to change my retainer amount?',
        answer: 'Contact your attorney or paralegal directly via the message team button. Retainer adjustments require legal-team approval before they can be processed.'
    },
    {
        id: 'faq-5',
        question: 'How do I view my billing history?',
        answer: 'Your billing summary is shown on each matter card. For detailed invoice history, contact the finance team using the "Contact Finance" link in the sidebar.'
    },
    {
        id: 'faq-6',
        question: 'Can I add a new matter to my account?',
        answer: 'Yes — clients with existing matters can start a new matter request from the dashboard. You\'ll go through a brief intake process for each new legal issue.'
    },
    {
        id: 'faq-7',
        question: 'How do I reset my password?',
        answer: 'From the login page, click "Forgot password" and enter your username. You\'ll receive a one-time code via email to set a new password.'
    },
    {
        id: 'faq-8',
        question: 'Is my information secure?',
        answer: 'Yes. All portal communications are encrypted, and your information is protected under attorney-client privilege. We never share your data with third parties without consent.'
    }
];

export default class FaqPage extends LightningElement {
    faqs = PLACEHOLDER_FAQS;

    // Allow only one section open at a time (cleaner UX). If Skylar prefers
    // multi-open, change handleSectionToggle to no-op.
    activeSectionName = '';

    handleSectionToggle(event) {
        this.activeSectionName = event.detail.openSections;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', { bubbles: true, composed: true }));
    }
}