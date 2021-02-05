import Mousetrap from 'mousetrap';
import findAndFollowLink from '../../lib/utils/navigation_utility';
import ShortcutsNavigation from './shortcuts_navigation';
import { keysFor, EDIT_WIKI_PAGE } from './keybindings';

export default class ShortcutsWiki extends ShortcutsNavigation {
  constructor() {
    super();
    Mousetrap.bind(keysFor(EDIT_WIKI_PAGE), ShortcutsWiki.editWiki);
  }

  static editWiki() {
    findAndFollowLink('.js-wiki-edit');
  }
}
