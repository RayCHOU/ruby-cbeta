require 'minitest/autorun'
require_relative '../lib/cbeta'

class CBETATest < Minitest::Test
  def test_cbeta
    assert_equal 'GA/GA009/GA009n0008.xml', CBETA.linehead_to_xml_file_path('GA009n0008_p0003a01')
    assert_equal 'J/J36/J36nB348.xml', CBETA.linehead_to_xml_file_path('J36nB348_p0284c01')
    assert_equal '【太虛】', CBETA.new.get_canon_symbol('TX')
    assert_equal 'CC001', CBETA.normalize_vol('CC1')
    
    assert_equal 1, CBETA.juan_across_vol('GA036', 'GA0037', 2)
    assert_equal 2, CBETA.juan_across_vol('GA037', 'GA0037', 2)
    assert_equal 2, CBETA.juan_across_vol('GA037', 'GA0037')
    assert_nil CBETA.juan_across_vol('T0001', 1)
  end
end

class GaijiTest < Minitest::Test
  def setup
    @gaiji = CBETA::Gaiji.new
  end

  def test_to_s
    refute_nil(@gaiji.to_s('CB00597'))
    refute_nil(@gaiji.to_s('CB00011')) # unicode, 通用字 都沒有
  end
end
