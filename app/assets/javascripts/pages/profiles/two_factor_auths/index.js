import $ from 'jquery';
import U2FRegister from '~/u2f/register';
import WebAuthnRegister from '~/webauthn/register';
import { parseBoolean } from '~/lib/utils/common_utils';

document.addEventListener('DOMContentLoaded', () => {
  const twoFactorNode = document.querySelector('.js-two-factor-auth');
  const skippable = parseBoolean(twoFactorNode.dataset.twoFactorSkippable);

  if (skippable) {
    const button = `<a class="btn btn-sm btn-warning float-right" data-qa-selector="configure_it_later_button" data-method="patch" href="${twoFactorNode.dataset.two_factor_skip_url}">Configure it later</a>`;
    const flashAlert = document.querySelector('.flash-alert');
    if (flashAlert) flashAlert.insertAdjacentHTML('beforeend', button);
  }

  if (gon.features && gon.features.webauthn) {
    const webauthnRegister = new WebAuthnRegister($('#js-register-webauthn'), gon.webauthn);
    webauthnRegister.start();
  } else {
    const u2fRegister = new U2FRegister($('#js-register-u2f'), gon.u2f);
    u2fRegister.start();
  }
});
