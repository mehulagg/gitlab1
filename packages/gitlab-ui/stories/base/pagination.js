import { storiesOf } from "@storybook/vue";
import { withKnobs, number } from '@storybook/addon-knobs';
import { Pagination } from '../../index';

const components = {
  'gl-pagination': Pagination,
};

function generateProps({
  page = 3,
  perPage = 10,
  totalItems = 200,
} = {}) {
  return {
    change: {
      type: Function,
      default: (current, past) => console.log(
        `switched from ${past} to ${current}`,
      ),
    },
    page: {
      type: Number,
      default: number('current page', page),
    },
    perPage: {
      type: Number,
      default: number('per page', perPage),
    },
    totalItems: {
      type: Number,
      default: number('total items', totalItems),
    },
  };
};

storiesOf("pagination", module)
  .addDecorator(withKnobs)
  .add("default", () => ({
    props: generateProps(),
    components,
    template: `<gl-pagination
      :change="change"
      :page="page"
      :per-page="perPage"
      :total-items="totalItems"
      />`,
  }))
  .add("small", () => ({
    props: generateProps(),
    components,
    template: `<gl-pagination
      size="sm"
      :change="change"
      :page="page"
      :per-page="perPage"
      :total-items="totalItems"
      />`,
  }))
  .add("large", () => ({
    props: generateProps(),
    components,
    template: `<gl-pagination
      size="lg"
      :change="change"
      :page="page"
      :per-page="perPage"
      :total-items="totalItems"
      />`,
  }));
