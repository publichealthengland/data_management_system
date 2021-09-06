require 'test_helper'

class ProjectDatasetLevelTest < ActiveSupport::TestCase
  test 'should notify casmanager and access approvers on dataset level approved update - not nil' do
    project = create_cas_project(project_purpose: 'test')
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    project_dataset = ProjectDataset.new(dataset: dataset, terms_accepted: nil)
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.create(access_level_id: 1, expiry_date: Time.zone.today + 1.week,
                                     project_dataset_id: project_dataset.id)
    project.reload_current_state

    notifications = Notification.where(title: 'Dataset Approval Level Status Change')

    # Should not send out notifications for changes when at Draft
    assert_no_difference 'notifications.count' do
      pdl.update(status_id: 2)
      pdl.update(status_id: 1)
    end

    project.transition_to!(workflow_states(:submitted))
    project.reload_current_state
    assert_equal 'SUBMITTED', project.current_state&.id

    assert_difference 'notifications.count', 4 do
      pdl.update(status_id: 2)
    end

    assert_equal notifications.last.body, "CAS application #{project.id} - Dataset 'Extra CAS " \
                                          "Dataset One' has been updated to Approval status of " \
                                          "'Approved' for level 1.\n\n"

    assert_difference 'notifications.count', 4 do
      pdl.update(status_id: 3)
    end

    assert_equal notifications.last.body, "CAS application #{project.id} - Dataset 'Extra CAS " \
                                          "Dataset One' has been updated to Approval status of " \
                                          "'Rejected' for level 1.\n\n"

    assert_no_difference 'notifications.count' do
      pdl.update(status_id: 1)
    end
  end

  test 'should notify user on dataset level approved update to not nil' do
    project = create_cas_project(project_purpose: 'test', owner: users(:no_roles))
    dataset = Dataset.find_by(name: 'Extra CAS Dataset One')
    project_dataset = ProjectDataset.new(dataset: dataset, terms_accepted: nil)
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.create(access_level_id: 1, expiry_date: Time.zone.today + 1.week,
                                     project_dataset_id: project_dataset.id)
    project.reload_current_state

    notifications = Notification.where(title: 'Dataset Approval Level Updated')

    # Should not send out notifications for changes when at Draft
    assert_no_difference 'notifications.count' do
      pdl.update(status_id: 2)
      pdl.update(status_id: 1)
    end

    project.transition_to!(workflow_states(:submitted))
    project.reload_current_state

    assert_difference 'notifications.count', 1 do
      pdl.update(status_id: 2)
    end

    assert_equal notifications.last.body, "Your CAS dataset access request for 'Extra CAS " \
                                          "Dataset One' has been updated to Approval status of " \
                                          "'Approved' for level 1.\n\n"

    assert_difference 'notifications.count', 1 do
      pdl.update(status_id: 3)
    end

    assert_equal notifications.last.body, "Your CAS dataset access request for 'Extra CAS " \
                                          "Dataset One' has been updated to Approval status of " \
                                          "'Rejected' for level 1.\n\n"

    assert_no_difference 'notifications.count' do
      pdl.update(status_id: 1)
    end
  end

  test 'should not notify dataset approver on dataset level approved update to nil' do
    project_dataset = ProjectDataset.new(dataset: dataset(83), terms_accepted: true)
    project = create_cas_project(owner: users(:no_roles))
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.create(access_level_id: 1, expiry_date: Time.zone.today + 1.week,
                                     project_dataset_id: project_dataset.id)
    pdl.update(status_id: 2)
    project.transition_to!(workflow_states(:submitted))

    assert_no_difference 'notifications.count' do
      pdl.update(status_id: 1)
    end
  end

  test 'set_decided_at_to_nil' do
    date_time_now = Time.zone.now
    project_dataset = ProjectDataset.new(dataset: dataset(83), terms_accepted: true)
    project = create_cas_project(owner: users(:no_roles))
    project.project_datasets << project_dataset
    pdl = ProjectDatasetLevel.create(access_level_id: 1, expiry_date: Time.zone.today + 1.week,
                                     project_dataset_id: project_dataset.id)
    pdl.update(status_id: 2, decided_at: date_time_now)
    project.transition_to!(workflow_states(:submitted))

    assert_equal pdl.decided_at, date_time_now

    pdl.update(status_id: 1)

    assert_nil pdl.decided_at
  end

  test 'level 2 and 3 default datasets should have expiry date set to 1 year on creation' do
    project_dataset = ProjectDataset.new(dataset: dataset(85), terms_accepted: true)
    assert project_dataset.dataset.cas_defaults?
    project = create_cas_project(owner: users(:no_roles))
    project.project_datasets << project_dataset
    no_expiry_pdl = ProjectDatasetLevel.create(access_level_id: 2,
                                               project_dataset_id: project_dataset.id)

    assert_equal 1.year.from_now.to_date, no_expiry_pdl.expiry_date

    expiry_pdl = ProjectDatasetLevel.create(access_level_id: 3, expiry_date: 2.years.from_now,
                                            project_dataset_id: project_dataset.id)
    assert_equal 1.year.from_now.to_date, expiry_pdl.expiry_date

    wrong_access_level = ProjectDatasetLevel.create(access_level_id: 1,
                                                    project_dataset_id: project_dataset.id)

    refute_equal 1.year.from_now.to_date, wrong_access_level.expiry_date

    project_dataset = ProjectDataset.new(dataset: dataset(83), terms_accepted: true)
    assert project_dataset.dataset.cas_extras?
    project.project_datasets << project_dataset
    wrong_dataset_type_and_date = ProjectDatasetLevel.create(access_level_id: 2,
                                                             expiry_date: 2.years.from_now,
                                                             project_dataset_id: project_dataset.id)

    refute_equal 1.year.from_now.to_date, wrong_dataset_type_and_date.expiry_date

    wrong_dataset_type_no_date = ProjectDatasetLevel.create(access_level_id: 3,
                                                            project_dataset_id: project_dataset.id)

    refute_equal 1.year.from_now.to_date, wrong_dataset_type_no_date.expiry_date
  end

  test 'expiry date must be present for level 1 and extra datasets' do
    project_dataset = ProjectDataset.new(dataset: dataset(85), terms_accepted: true)
    assert project_dataset.dataset.cas_defaults?
    project = create_cas_project(owner: users(:no_roles))
    project.project_datasets << project_dataset
    level_1_default_pdl = ProjectDatasetLevel.new(access_level_id: 1, selected: true)
    project_dataset.project_dataset_levels << level_1_default_pdl

    level_1_default_pdl.valid?
    assert level_1_default_pdl.errors.messages[:expiry_date].
      include?('expiry date must be present for all selected extra datasets and any selected ' \
               'level 1 default datasets')

    level_1_default_pdl.update(expiry_date: 1.month.from_now.to_date)
    level_1_default_pdl.valid?
    refute level_1_default_pdl.errors.messages[:expiry_date].
      include?('expiry date must be present for all selected extra datasets and any selected ' \
               'level 1 default datasets')

    level_2_default_pdl = ProjectDatasetLevel.new(access_level_id: 2, selected: true)
    project_dataset.project_dataset_levels << level_2_default_pdl

    level_2_default_pdl.valid?
    refute level_2_default_pdl.errors.messages[:expiry_date].
      include?('expiry date must be present for all selected extra datasets and any selected ' \
               'level 1 default datasets')

    project_dataset = ProjectDataset.new(dataset: dataset(83), terms_accepted: true)
    assert project_dataset.dataset.cas_extras?
    project.project_datasets << project_dataset

    level_2_extra_pdl = ProjectDatasetLevel.new(access_level_id: 2, selected: true)
    project_dataset.project_dataset_levels << level_2_extra_pdl

    level_2_extra_pdl.valid?
    refute level_2_default_pdl.errors.messages[:expiry_date].
      include?('expiry date must be present for all selected extra datasets and any selected ' \
               'level 1 default datasets')
  end

  test 'should validate uniqueness of status_id for requested approved and renewable' do
    project_dataset = ProjectDataset.new(dataset: dataset(86), terms_accepted: true)
    project = create_cas_project(owner: users(:no_roles))
    project.project_datasets << project_dataset
    status_1_l2_pdl = ProjectDatasetLevel.create(access_level_id: 2, selected: true,
                                                 project_dataset_id: project_dataset.id)
    status_1_l2_pdl_duplicate = ProjectDatasetLevel.create(access_level_id: 2, selected: true,
                                                           project_dataset_id: project_dataset.id)

    status_1_l2_pdl_duplicate.valid?
    assert status_1_l2_pdl_duplicate.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl_duplicate.update(access_level_id: 3)
    status_1_l2_pdl_duplicate.valid?
    refute status_1_l2_pdl_duplicate.errors.messages[:status_id].include?('has already been taken')

    project_dataset2 = ProjectDataset.new(dataset: dataset(85), terms_accepted: true)
    project.project_datasets << project_dataset2
    status_1_l2_pdl_duplicate.update(access_level_id: 2, project_dataset_id: project_dataset2.id)
    status_1_l2_pdl_duplicate.valid?
    refute status_1_l2_pdl_duplicate.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl_duplicate.update(project_dataset_id: project_dataset.id, status_id: 2)
    status_1_l2_pdl_duplicate.valid?
    refute status_1_l2_pdl_duplicate.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl.update(status_id: 2)
    status_1_l2_pdl.valid?
    assert status_1_l2_pdl.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl.update(status_id: 3)
    status_1_l2_pdl.valid?
    refute status_1_l2_pdl.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl_duplicate.update(status_id: 3)
    status_1_l2_pdl_duplicate.valid?
    refute status_1_l2_pdl_duplicate.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl_duplicate.update(status_id: 4)
    status_1_l2_pdl_duplicate.valid?
    refute status_1_l2_pdl_duplicate.errors.messages[:status_id].include?('has already been taken')

    status_1_l2_pdl.update(status_id: 4)
    status_1_l2_pdl.valid?
    assert status_1_l2_pdl.errors.messages[:status_id].include?('has already been taken')
  end
end
