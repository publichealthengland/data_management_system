require 'test_helper'

# Tests behaviour of the `BelongsToReferent` concern.
class BelongsToReferentTest < ActiveSupport::TestCase
  def setup
    @resource = create_contract(projects(:dummy_project))
  end

  test 'should belong_to a referent' do
    assert @resource.class.reflect_on_association(:referent)
    assert_kind_of ApplicationRecord, @resource.referent
  end

  test 'should be invalid without an associated referent' do
    @resource.referent = nil

    refute @resource.valid?
    assert_includes @resource.errors.details[:referent], error: :blank
  end

  test 'should return the GlobalID for the associated resource' do
    gid = @resource.referent.to_global_id

    assert_equal gid, @resource.referent_gid
  end

  test 'should allow related resource to be assigned via GlobalID' do
    referent = @resource.referent
    @resource.referent = nil

    @resource.referent_gid = referent.to_global_id

    assert_equal referent, @resource.referent
  end

  test 'should delegate :reference to related resource' do
    referent = @resource.referent

    referent.expects(:reference)
    @resource.referent_reference
  end
end
