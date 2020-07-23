// eslint-disable-next-line import/prefer-default-export
export const formHasError = (state) =>
  Object.keys(state.formErrors)
    .map((key) => state.formErrors[key])
    .some((val) => Boolean(val));
