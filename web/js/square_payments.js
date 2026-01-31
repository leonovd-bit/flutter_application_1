(function () {
  async function loadSquareSdk(env) {
    if (window.Square) {
      return;
    }

    const scriptId = 'square-payments-sdk';
    const existing = document.getElementById(scriptId);
    if (existing) {
      await new Promise((resolve, reject) => {
        existing.addEventListener('load', resolve, { once: true });
        existing.addEventListener('error', reject, { once: true });
      });
      return;
    }

    const script = document.createElement('script');
    script.id = scriptId;
    script.async = true;
    script.src = env === 'sandbox'
      ? 'https://sandbox.web.squarecdn.com/v1/square.js'
      : 'https://web.squarecdn.com/v1/square.js';

    await new Promise((resolve, reject) => {
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  window.initializeSquarePayments = async function (applicationId, locationId, elementId, env) {
    await loadSquareSdk(env || 'production');
    if (!window.Square) {
      throw new Error('Square SDK not available');
    }

    const payments = window.Square.payments(applicationId, locationId);
    const card = await payments.card();
    await card.attach('#' + elementId);
    window.__squareCard = card;
    return true;
  };

  window.tokenizeSquareCard = async function () {
    if (!window.__squareCard) {
      throw new Error('Square card is not initialized');
    }
    const result = await window.__squareCard.tokenize();
    if (result.status !== 'OK') {
      const errors = (result.errors || []).map(e => e.message).join('; ');
      throw new Error(errors || 'Square tokenization failed');
    }
    return result.token;
  };
})();
