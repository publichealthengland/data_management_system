require 'test_helper'

class HomePageTest < ActionDispatch::IntegrationTest
  test 'should return projects dashboard page for odr non-standard user' do
    sign_in users(:application_manager_three)

    visit root_path
    assert has_content?('Projects Dashboard')

    within '.navbar' do
      click_link('Data Management System')
    end
    assert_equal home_index_path, current_path
  end

  test 'should return projects index page for cas role user' do
    sign_in users(:cas_manager)

    visit root_path
    assert has_content?('Listing Projects')

    within '.navbar' do
      click_link('Data Management System')
    end
    assert_equal home_index_path, current_path
  end

  test 'should return home index page for standard user' do
    sign_in users(:no_roles)

    visit root_path
    assert has_content?('Welcome to Data Management System')

    within '.navbar' do
      click_link('Data Management System')
    end
    assert_equal home_index_path, current_path
  end
end