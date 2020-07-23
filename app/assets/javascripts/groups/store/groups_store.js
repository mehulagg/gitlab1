import { normalizeHeaders, parseIntPagination } from '../../lib/utils/common_utils';

export default class GroupsStore {
  constructor(hideProjects) {
    this.state = {};
    this.state.groups = [];
    this.state.pageInfo = {};
    this.hideProjects = hideProjects;
  }

  setGroups(rawGroups) {
    if (rawGroups && rawGroups.length) {
      this.state.groups = rawGroups.map((rawGroup) => this.formatGroupItem(rawGroup));
    } else {
      this.state.groups = [];
    }
  }

  setSearchedGroups(rawGroups) {
    const formatGroups = (groups) =>
      groups.map((group) => {
        const formattedGroup = this.formatGroupItem(group);
        if (formattedGroup.children && formattedGroup.children.length) {
          formattedGroup.children = formatGroups(formattedGroup.children);
        }
        return formattedGroup;
      });

    if (rawGroups && rawGroups.length) {
      this.state.groups = formatGroups(rawGroups);
    } else {
      this.state.groups = [];
    }
  }

  setGroupChildren(parentGroup, children) {
    const updatedParentGroup = parentGroup;
    updatedParentGroup.children = children.map((rawChild) => this.formatGroupItem(rawChild));
    updatedParentGroup.isOpen = true;
    updatedParentGroup.isChildrenLoading = false;
  }

  getGroups() {
    return this.state.groups;
  }

  setPaginationInfo(pagination = {}) {
    let paginationInfo;

    if (Object.keys(pagination).length) {
      const normalizedHeaders = normalizeHeaders(pagination);
      paginationInfo = parseIntPagination(normalizedHeaders);
    } else {
      paginationInfo = pagination;
    }

    this.state.pageInfo = paginationInfo;
  }

  getPaginationInfo() {
    return this.state.pageInfo;
  }

  formatGroupItem(rawGroupItem) {
    const groupChildren = rawGroupItem.children || [];
    const groupIsOpen = groupChildren.length > 0 || false;
    const childrenCount = this.hideProjects
      ? rawGroupItem.subgroup_count
      : rawGroupItem.children_count;

    return {
      id: rawGroupItem.id,
      name: rawGroupItem.name,
      fullName: rawGroupItem.full_name,
      description: rawGroupItem.markdown_description,
      visibility: rawGroupItem.visibility,
      avatarUrl: rawGroupItem.avatar_url,
      relativePath: rawGroupItem.relative_path,
      editPath: rawGroupItem.edit_path,
      leavePath: rawGroupItem.leave_path,
      canEdit: rawGroupItem.can_edit,
      canLeave: rawGroupItem.can_leave,
      type: rawGroupItem.type,
      permission: rawGroupItem.permission,
      children: groupChildren,
      isOpen: groupIsOpen,
      isChildrenLoading: false,
      isBeingRemoved: false,
      parentId: rawGroupItem.parent_id,
      childrenCount,
      projectCount: rawGroupItem.project_count,
      subgroupCount: rawGroupItem.subgroup_count,
      memberCount: rawGroupItem.number_users_with_delimiter,
      starCount: rawGroupItem.star_count,
      updatedAt: rawGroupItem.updated_at,
      pendingRemoval: rawGroupItem.marked_for_deletion,
    };
  }

  removeGroup(group, parentGroup) {
    const updatedParentGroup = parentGroup;
    if (updatedParentGroup.children && updatedParentGroup.children.length) {
      updatedParentGroup.children = parentGroup.children.filter((child) => group.id !== child.id);
    } else {
      this.state.groups = this.state.groups.filter((child) => group.id !== child.id);
    }
  }
}
