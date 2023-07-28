require 'minitest/autorun'
require_relative '../lib/cbeta'

class CBETATest < Minitest::Test
  def test_cbeta
    assert_equal CBETA.linehead_to_xml_file_path('GA009n0008_p0003a01'), 'GA/GA009/GA009n0008.xml'
    assert_equal CBETA.new.get_canon_symbol('TX'), '【太虛】'
    assert_equal CBETA.normalize_vol('CC1'), 'CC001'
  end
end