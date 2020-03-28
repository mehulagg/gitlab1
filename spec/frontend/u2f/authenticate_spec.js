import $ from 'jquery';
import U2FAuthenticate from '~/u2f/authenticate';
import 'vendor/u2f';
import MockU2FDevice from './mock_u2f_device';

describe('U2FAuthenticate', () => {
  let u2fDevice;
  let container;
  let component;

  preloadFixtures('u2f/authenticate.html');

  beforeEach(() => {
    loadFixtures('u2f/authenticate.html');
    u2fDevice = new MockU2FDevice();
    container = $('#js-authenticate-u2f');
    component = new U2FAuthenticate(
      container,
      '#js-login-u2f-form',
      {
        sign_requests: [],
      },
      document.querySelector('#js-login-2fa-device'),
      document.querySelector('.js-2fa-form'),
    );
  });

  describe('with u2f unavailable', () => {
    let oldu2f;

    beforeEach(() => {
      jest.spyOn(component, 'switchToFallbackUI').mockImplementation(() => {});
      oldu2f = window.u2f;
      window.u2f = null;
    });

    afterEach(() => {
      window.u2f = oldu2f;
    });

    it('falls back to normal 2fa', done => {
      component
        .start()
        .then(() => {
          expect(component.switchToFallbackUI).toHaveBeenCalled();
          done();
        })
        .catch(done.fail);
    });
  });

  describe('with u2f available', () => {
    beforeEach(done => {
      // bypass automatic form submission within renderAuthenticated
      jest.spyOn(component, 'renderAuthenticated').mockReturnValue(true);
      u2fDevice = new MockU2FDevice();

      component
        .start()
        .then(done)
        .catch(done.fail);
    });

    it('allows authenticating via a U2F device', () => {
      const inProgressMessage = container.find('p');

      expect(inProgressMessage.text()).toContain('Trying to communicate with your device');
      u2fDevice.respondToAuthenticateRequest({
        deviceData: 'this is data from the device',
      });

      expect(component.renderAuthenticated).toHaveBeenCalledWith(
        '{"deviceData":"this is data from the device"}',
      );
    });

    describe('errors', () => {
      it('displays an error message', () => {
        const setupButton = container.find('#js-login-u2f-device');
        setupButton.trigger('click');
        u2fDevice.respondToAuthenticateRequest({
          errorCode: 'error!',
        });
        const errorMessage = container.find('p');

        expect(errorMessage.text()).toContain('There was a problem communicating with your device');
      });

      it('allows retrying authentication after an error', () => {
        let setupButton = container.find('#js-login-u2f-device');
        setupButton.trigger('click');
        u2fDevice.respondToAuthenticateRequest({
          errorCode: 'error!',
        });
        const retryButton = container.find('#js-u2f-try-again');
        retryButton.trigger('click');
        setupButton = container.find('#js-login-u2f-device');
        setupButton.trigger('click');
        u2fDevice.respondToAuthenticateRequest({
          deviceData: 'this is data from the device',
        });

        expect(component.renderAuthenticated).toHaveBeenCalledWith(
          '{"deviceData":"this is data from the device"}',
        );
      });
    });
  });
});
