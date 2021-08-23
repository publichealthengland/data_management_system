require 'test_helper'

class CasDatasetApprovalTest < ActionDispatch::IntegrationTest
  test 'should be able to approve and reject datasets' do
    user = users(:cas_dataset_approver)
    ProjectDatasetLevelsController.any_instance.expects(:valid_otp?).twice.returns(false).then.returns(true)
    sign_in user

    project = create_cas_project(owner: users(:standard_user2))
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    pd = ProjectDataset.create(dataset: dataset, terms_accepted: true)
    project.project_datasets << pd
    pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week)
    pd.project_dataset_levels << pdl
    pd.project_dataset_levels << ProjectDatasetLevel.new(access_level_id: 2, expiry_date: Time.zone.today + 2.weeks)

    project.transition_to!(workflow_states(:submitted))
    visit cas_approvals_projects_path

    within '#my_dataset_approvals' do
      assert has_content?(project.id.to_s)
      click_link(href: "/projects/#{project.id}#!datasets", title: 'Details')
    end

    assert has_content?('Extra CAS Dataset One')

    assert_nil pdl.approved

    assert_changes -> { pdl.reload.approved }, from: nil, to: true do
      find("#approval_project_dataset_level_#{pdl.id}").click
      within_modal(selector: '#yubikey-challenge') do
        fill_in 'ndr_authenticate[otp]', with: 'defo a yubikey'
        click_button 'Submit'
      end
      within "#project_dataset_level_#{pdl.id}" do
        within '#decision_date' do
          assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
        end
        within '#request_type' do
          assert has_content?('New')
        end
        assert has_content?('APPROVED')
      end
    end

    assert_equal find('#project_status').text, 'Pending'

    pdl.update(approved: nil, decided_at: nil)

    visit project_path(project)
    click_link(href: '#datasets')

    assert_changes -> { pdl.reload.approved }, from: nil, to: false do
      within "#approvals_project_dataset_level_#{pdl.id}" do
        find('.btn-danger').click
      end
      within "#project_dataset_level_#{pdl.id}" do
        within '#decision_date' do
          assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
        end
        within '#request_type' do
          assert has_content?('New')
        end
        assert has_content?('DECLINED')
      end
    end

    assert_equal find('#project_status').text, 'Pending'
  end

  test 'should be able to reapply for a dataset if approval declined' do
    user = users(:no_roles)
    sign_in user

    project = create_cas_project(owner: users(:no_roles))
    project_dataset = ProjectDataset.new(dataset: dataset(86), terms_accepted: true)
    project.project_datasets << project_dataset
    l1_pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 2.months,
                                     selected: true)
    l2_pdl = ProjectDatasetLevel.new(access_level_id: 2, expiry_date: Time.zone.today + 2.months,
                                     selected: true)
    project_dataset.project_dataset_levels.push(l1_pdl, l2_pdl)

    project.transition_to!(workflow_states(:submitted))

    l1_pdl.update(approved: true, decided_at: Time.zone.now)
    l2_pdl.update(approved: true, decided_at: Time.zone.now)

    visit project_path(project)

    click_link(href: '#datasets')
    assert has_content?('Cas Defaults Dataset', count: 2)
    assert has_content?('APPROVED', count: 2)
    assert has_no_content?('Reapply')

    l1_pdl.update(approved: false, decided_at: Time.zone.now)
    l2_pdl.update(approved: false, decided_at: Time.zone.now)

    visit project_path(project)

    click_link(href: '#datasets')
    assert has_content?('Cas Defaults Dataset', count: 2)

    assert has_content?('DECLINED', count: 2)

    within "#project_dataset_level_#{l2_pdl.id}" do
      click_link('Reapply')
    end

    assert_equal 2, ProjectDatasetLevel.last.reload.access_level_id
    assert has_content?('Previous datasets')
    assert has_content?('Reapplication request created succesfully')

    within "#project_dataset_level_#{ProjectDatasetLevel.last.id}" do
      within '#decision_date' do
        assert has_no_content?
      end
      within '#request_type' do
        assert has_content?('Reapplication')
      end
      assert has_content?('PENDING')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Reapply')
    end

    within "#project_dataset_level_#{l2_pdl.id}" do
      within '#decision_date' do
        assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
      end
      assert has_content?('DECLINED')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Reapply')
    end

    assert_equal false, l2_pdl.reload.approved
    assert_equal false, l2_pdl.reload.current
    assert_nil ProjectDatasetLevel.last.reload.approved
    assert_equal true, ProjectDatasetLevel.last.reload.current

    within "#project_dataset_level_#{l1_pdl.id}" do
      click_button('Reapply')
    end

    within_modal(selector: '#modal-reapply') do
      assert has_content?('Reapplication for Cas Defaults Dataset level 1')
      fill_in('reapply_datepicker', with: '')
      click_button('Save')
    end

    assert has_content?('Reapplication failed - please provide a valid expiry date in the future')
    assert has_button?('Reapply')
    assert_equal 2, ProjectDatasetLevel.last.reload.access_level_id

    within "#project_dataset_level_#{l1_pdl.id}" do
      click_button('Reapply')
    end

    within_modal(selector: '#modal-reapply') do
      fill_in('reapply_datepicker', with: (Time.zone.now + 1.year).strftime('%d/%m/%Y)'))
      click_button('Save')
    end

    assert has_content?('Reapplication request created succesfully')
    assert has_no_button?('Reapply')
    assert_equal 1, ProjectDatasetLevel.last.reload.access_level_id

    within "#project_dataset_level_#{ProjectDatasetLevel.last.id}" do
      within '#decision_date' do
        assert has_no_content?
      end
      within '#request_type' do
        assert has_content?('Reapplication')
      end
      assert has_content?('PENDING')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Reapply')
    end

    within "#project_dataset_level_#{l1_pdl.id}" do
      within '#decision_date' do
        assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
      end
      assert has_content?('DECLINED')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Reapply')
    end

    assert_equal false, l1_pdl.reload.approved
    assert_equal false, l1_pdl.reload.current
    assert_nil ProjectDatasetLevel.last.reload.approved
    assert_equal true, ProjectDatasetLevel.last.reload.current
  end

  test 'should be able to apply for renewal of a dataset if within expiry period' do
    user = users(:no_roles)
    sign_in user

    project = create_cas_project(owner: users(:no_roles))
    project_dataset = ProjectDataset.new(dataset: dataset(86), terms_accepted: true)
    project.project_datasets << project_dataset
    l1_pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 2.months,
                                     selected: true)
    l2_pdl = ProjectDatasetLevel.new(access_level_id: 2, expiry_date: Time.zone.today + 2.months,
                                     selected: true)
    project_dataset.project_dataset_levels.push(l1_pdl, l2_pdl)

    project.transition_to!(workflow_states(:submitted))

    l1_pdl.update(approved: true, decided_at: Time.zone.now)
    l2_pdl.update(approved: true, decided_at: Time.zone.now)

    visit project_path(project)

    click_link(href: '#datasets')
    assert has_content?('Cas Defaults Dataset', count: 2)
    assert has_content?('APPROVED', count: 2)
    assert has_no_content?('Renew')

    l1_pdl.update(expiry_date: Time.zone.today + 1.week)
    l2_pdl.update(expiry_date: Time.zone.today + 1.week)

    visit project_path(project)

    click_link(href: '#datasets')
    assert has_content?('Cas Defaults Dataset')

    within "#project_dataset_level_#{l2_pdl.id}" do
      click_link('Renew')
    end

    assert has_content?('Previous datasets')
    assert has_content?('Renewal request created succesfully')
    assert_equal 2, ProjectDatasetLevel.last.reload.access_level_id

    within "#project_dataset_level_#{ProjectDatasetLevel.last.id}" do
      within '#decision_date' do
        assert has_no_content?
      end
      within '#request_type' do
        assert has_content?('Renewal')
      end
      assert has_content?('PENDING')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Renew')
    end

    within "#project_dataset_level_#{l2_pdl.id}" do
      within '#decision_date' do
        assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
      end
      assert has_content?('APPROVED')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Renew')
    end

    assert_equal true, l2_pdl.reload.approved
    assert_equal false, l2_pdl.reload.current
    assert_nil ProjectDatasetLevel.last.reload.approved
    assert_equal true, ProjectDatasetLevel.last.reload.current

    within "#project_dataset_level_#{l1_pdl.id}" do
      click_button('Renew')
    end

    within_modal(selector: '#modal-renewal') do
      assert has_content?('Renewal for Cas Defaults Dataset level 1')
      fill_in('renewal_datepicker', with: '')
      click_button('Save')
    end

    assert has_content?('Renewal failed - please provide a valid expiry date in the future')
    assert has_button?('Renew')
    assert_equal 2, ProjectDatasetLevel.last.reload.access_level_id

    within "#project_dataset_level_#{l1_pdl.id}" do
      click_button('Renew')
    end

    within_modal(selector: '#modal-renewal') do
      fill_in('renewal_datepicker', with: (Time.zone.now + 1.year).strftime('%d/%m/%Y)'))
      click_button('Save')
    end

    assert has_content?('Renewal request created succesfully')
    assert has_no_button?('Renew')
    assert_equal 1, ProjectDatasetLevel.last.reload.access_level_id

    within "#project_dataset_level_#{ProjectDatasetLevel.last.id}" do
      within '#decision_date' do
        assert has_no_content?
      end
      within '#request_type' do
        assert has_content?('Renewal')
      end
      assert has_content?('PENDING')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Renew')
    end

    within "#project_dataset_level_#{l1_pdl.id}" do
      within '#decision_date' do
        assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
      end
      assert has_content?('APPROVED')
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert has_no_link?('Renew')
    end

    assert_equal true, l1_pdl.reload.approved
    assert_equal false, l1_pdl.reload.current
    assert_nil ProjectDatasetLevel.last.reload.approved
    assert_equal true, ProjectDatasetLevel.last.reload.current
  end

  test 'should show applicant correct pending dataset status' do
    # Other statuses are covered in the test above
    user = users(:no_roles)
    sign_in user

    project = create_cas_project(owner: users(:no_roles))
    project_dataset = ProjectDataset.new(dataset: Dataset.find_by(name: 'Extra CAS Dataset One'),
                                         terms_accepted: nil)
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week)
    project_dataset.project_dataset_levels << pdl

    project.transition_to!(workflow_states(:submitted))

    visit project_path(project)

    click_link(href: '#datasets')
    assert has_content?('Extra CAS Dataset One')
    assert_equal find('#dataset_level_status').text, 'PENDING'
    within '#decision_date' do
      assert has_no_content?
    end
  end

  test 'should show cas_dataset approver correct dataset statuses' do
    user = users(:cas_dataset_approver)
    sign_in user

    project = create_cas_project(owner: users(:standard_user2))
    grant_dataset = ProjectDataset.new(dataset: Dataset.find_by(name: 'Extra CAS Dataset One'),
                                       terms_accepted: true)
    non_grant_dataset = ProjectDataset.new(dataset: Dataset.find_by(name: 'Extra CAS Dataset Two'),
                                           terms_accepted: true)
    project.project_datasets << grant_dataset
    project.project_datasets << non_grant_dataset
    grant_pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week)
    non_grant_pdl = ProjectDatasetLevel.new(access_level_id: 1, expiry_date: Time.zone.today + 1.week)
    grant_dataset.project_dataset_levels << grant_pdl
    non_grant_dataset.project_dataset_levels << non_grant_pdl

    project.transition_to!(workflow_states(:submitted))

    visit project_path(project)
    click_link(href: '#datasets')
    assert has_content?('Extra CAS Dataset One')
    assert has_content?('Extra CAS Dataset Two')

    within("#project_dataset_level_#{grant_pdl.id}") do
      assert has_css?('.btn-danger')
      assert has_css?('.btn-success')
      assert has_no_content?('PENDING')
      within '#decision_date' do
        assert has_no_content?
      end
    end

    within("#project_dataset_level_#{non_grant_pdl.id}") do
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert_equal find('#dataset_level_status').text, 'PENDING'
      within '#decision_date' do
        assert has_no_content?
      end
    end

    non_grant_pdl.approved = true
    non_grant_pdl.save!(validate: false)

    visit project_path(project)

    click_link(href: '#datasets')

    within("#project_dataset_level_#{non_grant_pdl.id}") do
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert_equal find('#dataset_level_status').text, 'APPROVED'
    end

    non_grant_pdl.approved = false
    non_grant_pdl.save!(validate: false)

    visit project_path(project)

    click_link(href: '#datasets')

    within("#project_dataset_level_#{non_grant_pdl.id}") do
      assert has_no_css?('.btn-danger')
      assert has_no_css?('.btn-success')
      assert_equal find('#dataset_level_status').text, 'DECLINED'
    end
  end

  test 'bulk approve button and highlighting of pending datasets should behave correctly' do
    project = create_cas_project(owner: users(:standard_user2))
    grant_default_dataset = ProjectDataset.new(dataset: dataset(86), terms_accepted: true)
    nogrant_extra_dataset = ProjectDataset.new(dataset: dataset(84), terms_accepted: true)
    project.project_datasets.push(grant_default_dataset, nogrant_extra_dataset)
    rejected_default_l1_pdl = ProjectDatasetLevel.new(access_level_id: 1, selected: true,
                                                      expiry_date: Time.zone.today + 1.week,
                                                      approved: false,
                                                      decided_at: Time.zone.now - 1.day)
    grant_default_l1_pdl = ProjectDatasetLevel.new(access_level_id: 1, selected: true,
                                                   expiry_date: Time.zone.today + 1.week)
    grant_default_l2_pdl = ProjectDatasetLevel.new(access_level_id: 2, selected: true,
                                                   expiry_date: Time.zone.today + 1.year)
    grant_default_l3_pdl = ProjectDatasetLevel.new(access_level_id: 3, selected: true,
                                                   expiry_date: Time.zone.today + 1.year)
    no_grant_extra_l2_pdl = ProjectDatasetLevel.new(access_level_id: 2, selected: true,
                                                    expiry_date: Time.zone.today + 1.year)
    grant_default_dataset.project_dataset_levels.push(rejected_default_l1_pdl, grant_default_l1_pdl,
                                                      grant_default_l2_pdl, grant_default_l3_pdl)
    nogrant_extra_dataset.project_dataset_levels << no_grant_extra_l2_pdl

    project.transition_to!(workflow_states(:submitted))

    sign_in users(:standard_user2)

    visit project_path(project)
    click_link(href: '#datasets')
    assert has_content?('Cas Defaults Dataset', count: 4)
    assert has_content?('Extra CAS Dataset Two', count: 1)
    assert has_no_content?('Approve level 2 and 3 default datasets')

    assert find("#project_dataset_level_#{rejected_default_l1_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l1_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l2_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l3_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{no_grant_extra_l2_pdl.id}")[:class].
      exclude?('dataset_highlight')

    sign_out users(:standard_user2)
    sign_in users(:cas_access_and_dataset_approver)

    visit project_path(project)
    click_link(href: '#datasets')
    assert has_content?('Cas Defaults Dataset', count: 4)
    assert has_content?('Extra CAS Dataset Two', count: 1)
    assert has_button?('Approve level 2 and 3 default datasets')

    assert find("#project_dataset_level_#{rejected_default_l1_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l1_pdl.id}")[:class].
      include?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l2_pdl.id}")[:class].
      include?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l3_pdl.id}")[:class].
      include?('dataset_highlight')
    assert find("#project_dataset_level_#{no_grant_extra_l2_pdl.id}")[:class].
      exclude?('dataset_highlight')

    assert_equal false, rejected_default_l1_pdl.reload.approved
    assert_nil grant_default_l1_pdl.reload.approved
    assert_nil grant_default_l2_pdl.reload.approved
    assert_nil grant_default_l3_pdl.reload.approved
    assert_nil no_grant_extra_l2_pdl.reload.approved

    click_button('Approve level 2 and 3 default datasets')

    assert has_no_button?('Approve level 2 and 3 default datasets')

    within "#project_dataset_level_#{rejected_default_l1_pdl.id}" do
      within '#decision_date' do
        assert has_content?((Time.zone.now - 1.day).strftime('%d/%m/%Y'))
      end
      assert has_content?('DECLINED')
    end

    within "#project_dataset_level_#{grant_default_l1_pdl.id}" do
      within '#decision_date' do
        assert has_no_content?
      end
      assert find('.btn-danger')
      assert find('.btn-success')
      assert has_no_content?('APPROVED')
    end

    within "#project_dataset_level_#{grant_default_l2_pdl.id}" do
      within '#decision_date' do
        assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
      end
      assert has_content?('APPROVED')
    end

    within "#project_dataset_level_#{grant_default_l3_pdl.id}" do
      within '#decision_date' do
        assert has_content?(Time.zone.now.strftime('%d/%m/%Y'))
      end
      assert has_content?('APPROVED')
    end

    within "#project_dataset_level_#{no_grant_extra_l2_pdl.id}" do
      within '#decision_date' do
        assert has_no_content?
      end
      assert has_content?('PENDING')
    end

    assert find("#project_dataset_level_#{rejected_default_l1_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l1_pdl.id}")[:class].
      include?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l2_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{grant_default_l3_pdl.id}")[:class].
      exclude?('dataset_highlight')
    assert find("#project_dataset_level_#{no_grant_extra_l2_pdl.id}")[:class].
      exclude?('dataset_highlight')

    assert_equal false, rejected_default_l1_pdl.reload.approved
    assert_nil grant_default_l1_pdl.reload.approved
    assert_equal true, grant_default_l2_pdl.reload.approved
    assert_equal true, grant_default_l3_pdl.reload.approved
    assert_nil no_grant_extra_l2_pdl.reload.approved

    assert has_no_content?('Approve Access')

    # make decision on final default dataset
    within "#project_dataset_level_#{grant_default_l1_pdl.id}" do
      find('.btn-danger').click
    end

    assert has_content?('Approve Access')
  end
end
