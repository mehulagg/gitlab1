<script>
import { GlButton } from '@gitlab/ui';
import { mapState, mapActions } from 'vuex';

export default {
  components: {
    GlButton,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapState(['settings']),
  },
  methods: {
    ...mapActions(['requestEditRule', 'requestDeleteRule']),
  },
};
</script>

<template>
  <div>
    <gl-button @click="requestEditRule(rule)">
      <span>{{ __('Edit') }}</span>
    </gl-button>
    <gl-button
      class="gl-ml-3 btn btn-inverted"
      variant="danger"
      category="primary"
      icon="remove"
      :aria-label="__('Remove')"
      @click="requestDeleteRule(rule)"
    />
  </div>
</template>
