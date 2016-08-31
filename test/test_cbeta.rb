require 'minitest/autorun'
require 'cbeta'

class CBETATest < Minitest::Test
  def test_cbeta
    assert_equal CBETA.linehead_to_xml_file_path('GA009n0008_p0003a01'), 'GA/GA009/GA009n0008.xml'
  end
  
  def test_gaiji_zhuyin
    g = CBETA::Gaiji.new

    assert_equal ['ㄍㄢˇ', 'ㄍㄢ', 'ㄧㄤˊ', 'ㄇㄧˇ', 'ㄇㄧㄝ', 'ㄒㄧㄤˊ'],
      g.zhuyin("CB00023")

    assert_equal "[(王*巨)/木]",
      g['CB00006']['zzs']
  end
end