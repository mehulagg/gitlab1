import { range as rge, throttle } from 'lodash';
import DirtySubmitForm from '~/dirty_submit/dirty_submit_form';
import { getInputValue, setInputValue, createForm } from './helper';

jest.mock('lodash/throttle', () => jest.fn((fn) => fn));
const lodash = jest.requireActual('lodash');

function expectToToggleDisableOnDirtyUpdate(submit, input) {
  const originalValue = getInputValue(input);

  expect(submit.disabled).toBe(true);

  setInputValue(input, `${originalValue} changes`);
  expect(submit.disabled).toBe(false);
  setInputValue(input, originalValue);
  expect(submit.disabled).toBe(true);
}

describe('DirtySubmitForm', () => {
  describe('submit button tests', () => {
    it('disables submit until there are changes', () => {
      const { form, input, submit } = createForm();

      new DirtySubmitForm(form); // eslint-disable-line no-new

      expectToToggleDisableOnDirtyUpdate(submit, input);
    });

    it('disables submit until there are changes when initializing with a falsy value', () => {
      const { form, input, submit } = createForm();
      input.value = '';

      new DirtySubmitForm(form); // eslint-disable-line no-new

      expectToToggleDisableOnDirtyUpdate(submit, input);
    });

    it('disables submit until there are changes for radio inputs', () => {
      const { form, input, submit } = createForm('radio');

      new DirtySubmitForm(form); // eslint-disable-line no-new

      expectToToggleDisableOnDirtyUpdate(submit, input);
    });

    it('disables submit until there are changes for checkbox inputs', () => {
      const { form, input, submit } = createForm('checkbox');

      new DirtySubmitForm(form); // eslint-disable-line no-new

      expectToToggleDisableOnDirtyUpdate(submit, input);
    });
  });

  describe('`onChange` argument', () => {
    it('defaults to a function that returns `undefined`', () => {
      const { form } = createForm('checkbox');

      const dirtySubmitForm = new DirtySubmitForm(form); // eslint-disable-line no-new

      expect(dirtySubmitForm.onChange()).toBeUndefined();
    });

    it('is called when an input changes', () => {
      const { form, input } = createForm();
      const onChange = jest.fn();

      new DirtySubmitForm(form, onChange); // eslint-disable-line no-new

      setInputValue(input, 'changed');

      expect(onChange).toHaveBeenCalled();
    });
  });

  describe('throttling tests', () => {
    beforeEach(() => {
      throttle.mockImplementation(lodash.throttle);
      jest.useFakeTimers();
    });

    afterEach(() => {
      throttle.mockReset();
    });

    it('throttles updates when rapid changes are made to a single form element', () => {
      const { form, input } = createForm();
      const updateDirtyInputSpy = jest.spyOn(new DirtySubmitForm(form), 'updateDirtyInput');

      rge(10).forEach((i) => {
        setInputValue(input, `change ${i}`, false);
      });

      jest.runOnlyPendingTimers();

      expect(updateDirtyInputSpy).toHaveBeenCalledTimes(1);
    });

    it('does not throttle updates when rapid changes are made to different form elements', () => {
      const form = document.createElement('form');
      const range = rge(10);
      range.forEach((i) => {
        form.innerHTML += `<input type="text" name="input-${i}" class="js-input-${i}"/>`;
      });

      const updateDirtyInputSpy = jest.spyOn(new DirtySubmitForm(form), 'updateDirtyInput');

      range.forEach((i) => {
        const input = form.querySelector(`.js-input-${i}`);
        setInputValue(input, `change`, false);
      });

      jest.runOnlyPendingTimers();

      expect(updateDirtyInputSpy).toHaveBeenCalledTimes(range.length);
    });
  });
});
