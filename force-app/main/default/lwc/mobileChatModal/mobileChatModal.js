import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import createFutureErrorRecord from "@salesforce/apex/Utility.createFutureErrorRecord";
import createThread from '@salesforce/apex/OpenAIAssistantService.createThread';
import sendMessageAndRun from '@salesforce/apex/OpenAIAssistantService.sendMessageAndRun';
import pollRunStatus from '@salesforce/apex/OpenAIAssistantService.pollRunStatus';
import getAssistantMessages from '@salesforce/apex/OpenAIAssistantService.getAssistantMessages';

export default class MobileChatModal extends LightningModal {
  @api srcUrl;
  
connectedCallback() {
  console.log("connectedCallback fired");
  createThread()
    .then(result => {
        const data = JSON.parse(result);
        this.threadId = data.id;
        this.appendMessage(
          'Welcome to Modern Family Law!<br><br>I can help answer any questions you have as you go through your onboarding activities. Let me know if you need any assistance.',
          'bot',
          true
        );
    })
    .catch(error => {
      createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.createThread'}) ;
      console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
    });          
}

  handleClose() {
    this.close('closed'); // you can return a value to the opener
  }

  // --- Chatbot State ---
    threadId;
    userMessage = '';
    isThinking = false;
  
    // --- Input change handler ---
    handleInput(event) {
      this.userMessage = event.target.value;
    }
  
    handleKeyDown(event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        this.handleSendMessage();
      }
    }
  
    // --- Handle Send Button ---
    handleSendMessage() {
      console.log("clicked send");
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
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.createThread'}) ;
            console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
          });
      } else {
        sendMessageAndRun({ threadId: this.threadId, userMessage: messageToSend })
          .then(processRun)
          .catch(error => {
            this.removeThinkingIndicator(thinkingId);
            this.isThinking = false;
            createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.sendMessageAndRun'}) ;
            console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);              
          });
      }
    }
  
    // --- Append message to DOM ---
   appendMessage(text, sender, isHtml = false) {
    const container = this.template.querySelector('.mobile-messages-container');
    const scrollWrapper = this.template.querySelector('.chat-box');
  
    if (container) {
      const el = container.ownerDocument.createElement('div');
      el.classList.add('message', sender);
      el.innerHTML = isHtml ? text : '';
      if (!isHtml) el.textContent = text;
  
      container.appendChild(el);
  
      // ✅ Scroll to bottom
      if (scrollWrapper) {
        scrollWrapper.scrollTop = scrollWrapper.scrollHeight;
      }
    } else {
      console.error('.mobile-messages-container not found');
    }
  }
  
    // --- Append thinking indicator ---
    appendThinkingIndicator() {
      
      const container = this.template.querySelector('.mobile-messages-container');
      const el = container.ownerDocument.createElement('div');
      el.classList.add('message', 'bot', 'thinking');
      el.innerHTML = '<em>Thinking<span class="dots">...</span></em>';
      const id = `thinking-${Date.now()}`;
      el.id = id;
      container.appendChild(el);
      container.scrollTop = container.scrollHeight;
  
      // Animate dots
      const dots = el.querySelector('.dots');
      let dotCount = 3;
      const interval = setInterval(() => {
        dots.textContent = '.'.repeat(dotCount);
        dotCount = (dotCount % 6) + 1;
      }, 500);
  
      el.dataset.intervalId = interval;
      return id;
    }
  
    // --- Remove thinking indicator ---
    removeThinkingIndicator(id) {
      const el = this.template.querySelector(`#${id}`);
      if (el) {
        const intervalId = el.dataset.intervalId;
        if (intervalId) clearInterval(parseInt(intervalId));
        el.remove();
      }
    }
  
    // --- Poll run status ---
    pollStatus(threadId, runId, thinkingId) {
      pollRunStatus({ threadId, runId })
        .then(result => {
          const data = JSON.parse(result);
          const status = data.status;
  
          if (status === 'completed') {
            this.fetchAssistantReply(threadId, thinkingId);
          } else if (['queued', 'in_progress'].includes(status)) {
            setTimeout(() => this.pollStatus(threadId, runId, thinkingId), 1000);
          } else {
            this.removeThinkingIndicator(thinkingId);
            this.isThinking = false;
            console.warn('Run failed or cancelled:', status);
          }
        })
        .catch(error => {
          this.removeThinkingIndicator(thinkingId);
          this.isThinking = false;
          createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.pollStatus'}) ;
          console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);           
        });
    }
  
    // --- Get assistant message from thread ---
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
          createFutureErrorRecord( {exceptionMessage: error.message ?? error.body.message, stackTrace: error.stack ?? error.body.stackTrace, lineNum: 0, errortype: 'Javascript', procname: 'virtualAccountCreater.getAssistanMessages'}) ;
          console.error('Exception thrown:  ', error, 'stack trace:  ', error.stack);            
        });
    }
  
    // --- Format bot reply with markdown-like styling ---
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
}