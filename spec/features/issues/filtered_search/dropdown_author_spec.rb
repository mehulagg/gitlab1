require 'rails_helper'

describe 'Dropdown author', js: true, feature: true do
  include WaitForAjax

  let!(:project) { create(:empty_project) }
  let!(:user) { create(:user, name: 'administrator', username: 'root') }
  let!(:user_john) { create(:user, name: 'John', username: 'th0mas') }
  let!(:user_jacob) { create(:user, name: 'Jacob', username: 'otter32') }
  let(:filtered_search) { find('.filtered-search') }
  let(:js_dropdown_author) { '#js-dropdown-author' }

  def send_keys_to_filtered_search(input)
    input.split("").each do |i|
      filtered_search.send_keys(i)
      sleep 5
      wait_for_ajax
    end
  end

  def dropdown_author_size
    page.all('#js-dropdown-author .filter-dropdown .filter-dropdown-item').size
  end

  def click_author(text)
    find('#js-dropdown-author .filter-dropdown .filter-dropdown-item', text: text).click
  end

  before do
    project.team << [user, :master]
    project.team << [user_john, :master]
    project.team << [user_jacob, :master]
    login_as(user)
    create(:issue, project: project)

    visit namespace_project_issues_path(project.namespace, project)
  end

  describe 'behavior' do
    it 'opens when the search bar has author:' do
      filtered_search.set('author:')

      expect(page).to have_css(js_dropdown_author, visible: true)
    end

    it 'closes when the search bar is unfocused' do
      find('body').click()

      expect(page).to have_css(js_dropdown_author, visible: false)
    end

    it 'should show loading indicator when opened' do
      filtered_search.set('author:')

      expect(page).to have_css('#js-dropdown-author .filter-dropdown-loading', visible: true)
    end

    it 'should hide loading indicator when loaded' do
      send_keys_to_filtered_search('author:')

      expect(page).not_to have_css('#js-dropdown-author .filter-dropdown-loading')
    end

    it 'should load all the authors when opened' do
      send_keys_to_filtered_search('author:')

      expect(dropdown_author_size).to eq(3)
    end
  end

  describe 'filtering' do
    before do
      filtered_search.set('author')
      send_keys_to_filtered_search(':')
    end

    it 'filters by name' do
      send_keys_to_filtered_search('ja')

      expect(dropdown_author_size).to eq(1)
    end

    it 'filters by case insensitive name' do
      send_keys_to_filtered_search('Ja')

      expect(dropdown_author_size).to eq(1)
    end

    it 'filters by username with symbol' do
      send_keys_to_filtered_search('@ot')

      expect(dropdown_author_size).to eq(2)
    end

    it 'filters by username without symbol' do
      send_keys_to_filtered_search('ot')

      expect(dropdown_author_size).to eq(2)
    end

    it 'filters by case insensitive username without symbol' do
      send_keys_to_filtered_search('OT')

      expect(dropdown_author_size).to eq(2)
    end
  end

  describe 'selecting from dropdown' do
    before do
      filtered_search.set('author')
      send_keys_to_filtered_search(':')
    end

    it 'fills in the author username when the author has not been filtered' do
      click_author(user_jacob.name)

      expect(page).to have_css(js_dropdown_author, visible: false)
      expect(filtered_search.value).to eq("author:@#{user_jacob.username}")
    end

    it 'fills in the author username when the author has been filtered' do
      click_author(user.name)

      expect(page).to have_css(js_dropdown_author, visible: false)
      expect(filtered_search.value).to eq("author:@#{user.username}")
    end
  end

  describe 'input has existing content' do
    it 'opens author dropdown with existing search term' do
      filtered_search.set('searchTerm author:')

      expect(page).to have_css(js_dropdown_author, visible: true)
    end

    it 'opens author dropdown with existing assignee' do
      filtered_search.set('assignee:@user author:')

      expect(page).to have_css(js_dropdown_author, visible: true)
    end

    it 'opens author dropdown with existing label' do
      filtered_search.set('label:~bug author:')

      expect(page).to have_css(js_dropdown_author, visible: true)
    end

    it 'opens author dropdown with existing milestone' do
      filtered_search.set('milestone:%v1.0 author:')

      expect(page).to have_css(js_dropdown_author, visible: true)
    end
  end
end
