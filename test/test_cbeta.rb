require 'minitest/autorun'
require_relative '../lib/cbeta'

class CBETATest < Minitest::Test
  def test_cbeta
    assert_equal '【太虛】', CBETA.new.get_canon_symbol('TX')
    assert_equal 'GA0008', CBETA.get_work_id_from_linehead('GA009n0008_p0003a01')
    assert_equal 'GA/GA009/GA009n0008.xml', CBETA.linehead_to_xml_file_path('GA009n0008_p0003a01')
    assert_equal 'J/J36/J36nB348.xml', CBETA.linehead_to_xml_file_path('J36nB348_p0284c01')
    assert_equal 'CC001', CBETA.normalize_vol('CC1')
    
    assert_equal 1, CBETA.juan_across_vol('GA036', 'GA0037', 2)
    assert_equal 2, CBETA.juan_across_vol('GA037', 'GA0037', 2)
    assert_equal 2, CBETA.juan_across_vol('GA037', 'GA0037')
    assert_nil CBETA.juan_across_vol('T0001', 1)
  end
end

# CANON / WORK_PART 是 alternation, 必須自帶 non-capturing group,
# 否則插值後 ^ 只綁第一個選項、$ 只綁最後一個選項,
# 雙字母藏經編號 (CC, DA, GA, GB, LC, TX, YP, ZS, ZW) 會變成「任意位置比對」。
class CanonRegexpTest < Minitest::Test
  def test_canon_id
    CBETA::SORT_ORDER.each do |canon|
      assert_match(CBETA::CANON_ID, canon, "#{canon} 應該是合法的藏經 ID")
    end
  end

  # 這些字串「含有」雙字母藏經編號, 但整體並不是藏經 ID
  def test_canon_id_not_matching_substring
    [
      'ZS0001 正史佛教資料類編',
      'TX0001 佛學常識',
      'META-INF',
      'tmpZW',
      'T0001'
    ].each do |s|
      refute_match(CBETA::CANON_ID, s, "#{s.inspect} 不應該被視為藏經 ID")
    end
  end

  def test_work_id
    %w[T0001 T0150A T0128a JA041 JB271 ZWa073 ZS0001 GA0008].each do |s|
      assert_match(CBETA::WORK_ID, s, "#{s} 應該是合法的典籍編號")
    end
  end

  def test_work_id_not_matching_substring
    ['T', 'ZS', 'ZS0001 正史佛教資料類編', 'abcZWdef', 'T00011'].each do |s|
      refute_match(CBETA::WORK_ID, s, "#{s.inspect} 不應該被視為典籍編號")
    end
  end

  # CANON 加上 non-capturing group 之後, capture 編號不能位移
  def test_capture_group_numbering
    m = 'ZS01n0001_p0001a01'.match(/\A(#{CBETA::CANON})(\d{2,3})n(#{CBETA::WORK_PART})/)
    refute_nil m
    assert_equal 'ZS', m[1]
    assert_equal '01', m[2]
    assert_equal '0001', m[3]
  end

  def test_basename
    assert_match(/\A#{CBETA::BASENAME}\z/, 'GA010n0009')
    assert_match(/\A#{CBETA::BASENAME}\z/, 'ZS01n0001')
    assert_match(/\A#{CBETA::BASENAME}\z/, 'T25n1510a')
  end

  # 藏經 ID 的取出不受影響 (capture group 包在外面)
  def test_get_canon_id
    assert_equal 'ZS', CBETA.get_canon_id_from_work_id('ZS0001')
    assert_equal 'ZW', CBETA.get_canon_id_from_linehead('ZW12n0101_p0001a01')
    assert_equal 'GA', CBETA.get_canon_from_vol('GA009')
    assert_equal 'T', CBETA.get_canon_id_from_work_id('T0001')
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
