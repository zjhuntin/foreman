require 'test_helper'
require 'unit/compute_resources/compute_resource_test_helpers'

class OvirtTest < ActiveSupport::TestCase
  include ComputeResourceTestHelpers

  test "#associated_host matches any NIC" do
    host = FactoryGirl.create(:host, :mac => 'ca:d0:e6:32:16:97')
    cr = FactoryGirl.build(:ovirt_cr)
    iface1 = mock('iface1', :mac => '36:48:c5:c9:86:f2')
    iface2 = mock('iface2', :mac => 'ca:d0:e6:32:16:97')
    vm = mock('vm', :interfaces => [iface1, iface2])
    assert_equal host, as_admin { cr.associated_host(vm) }
  end

  describe "find_vm_by_uuid" do
    it "raises RecordNotFound when the vm does not exist" do
      cr = mock_cr_servers(Foreman::Model::Ovirt.new, empty_servers)
      assert_find_by_uuid_raises(ActiveRecord::RecordNotFound, cr)
    end

    it "raises RecordNotFound when the compute raises retrieve error" do
      cr = mock_cr_servers(Foreman::Model::Ovirt.new, servers_raising_exception(OVIRT::OvirtException.new('VM not found')))
      assert_find_by_uuid_raises(ActiveRecord::RecordNotFound, cr)
    end
  end

  describe "associating operating system" do
    setup do
      operating_systems_xml = Nokogiri::XML(File.read('test/fixtures/ovirt_operating_systems.xml'))
      ovirt_oses = operating_systems_xml.xpath('/operating_systems/operating_system').map do |os|
        OVIRT::OperatingSystem.new(self, os)
      end
      @compute_resource = FactoryGirl.build(:ovirt_cr).tap do |compute_resource|
        compute_resource.stubs(:available_operating_systems).returns(ovirt_oses)
      end
      @host = FactoryGirl.build(:host, :mac => 'ca:d0:e6:32:16:97')
    end

    it 'maps operating system to ovirt operating systems' do
      @compute_resource.determine_os_type(@host).must_equal "other_linux"

      @host.operatingsystem = operatingsystems(:redhat)
      @compute_resource.determine_os_type(@host).must_equal "rhel_6"

      @host.architecture = architectures(:x86_64)
      @compute_resource.determine_os_type(@host).must_equal "rhel_6x64"

      @host.operatingsystem = operatingsystems(:ubuntu1210)
      @compute_resource.determine_os_type(@host).must_equal "ubuntu_12_10"
    end
  end
end
