import $ from 'jquery';
import _ from 'lodash-es';
import axios from '~/lib/utils/axios_utils';
import flash from '~/flash';
import { __ } from '~/locale';
import { textColorForBackground } from '~/lib/utils/color_utils';

export default () => {
  const $broadcastMessageColor = $('input#broadcast_message_color');
  const $broadcastMessagePreview = $('div.broadcast-message-preview');
  $broadcastMessageColor.on('input', function onMessageColorInput() {
    const previewColor = $(this).val();
    $broadcastMessagePreview.css('background-color', previewColor);
  });

  $('input#broadcast_message_font').on('input', function onMessageFontInput() {
    const previewColor = $(this).val();
    $broadcastMessagePreview.css('color', previewColor);
  });

  const $broadcastMessage = $('textarea#broadcast_message_message');
  const previewPath = $broadcastMessage.data('previewPath');
  const $jsBroadcastMessagePreview = $('.js-broadcast-message-preview');

  $broadcastMessage.on(
    'input',
    _.debounce(function onMessageInput() {
      const message = $(this).val();
      if (message === '') {
        $jsBroadcastMessagePreview.text(__('Your message here'));
      } else {
        axios
          .post(previewPath, {
            broadcast_message: {
              message,
            },
          })
          .then(({ data }) => {
            $jsBroadcastMessagePreview.html(data.message);
          })
          .catch(() => flash(__('An error occurred while rendering preview broadcast message')));
      }
    }, 250),
  );

  const updateColorPreview = () => {
    const selectedBackgroundColor = $broadcastMessageColor.val();
    const contrastTextColor = textColorForBackground(selectedBackgroundColor);

    // save contrastTextColor to hidden input field
    $('input.text-font-color').val(contrastTextColor);

    // Updates the preview color with the hex-color input
    const selectedColorStyle = {
      backgroundColor: selectedBackgroundColor,
      color: contrastTextColor,
    };

    $('.label-color-preview').css(selectedColorStyle);

    return $broadcastMessagePreview.css(selectedColorStyle);
  };

  const setSuggestedColor = e => {
    const color = $(e.currentTarget).data('color');
    $broadcastMessageColor
      .val(color)
      // Notify the form, that color has changed
      .trigger('input');
    updateColorPreview();
    return e.preventDefault();
  };

  $(document).on('click', '.suggest-colors a', setSuggestedColor);
};
