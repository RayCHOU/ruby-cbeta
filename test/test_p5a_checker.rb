require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/cbeta'
require_relative '../lib/cbeta/p5a_checker'

class P5aCheckerLbTest < Minitest::Test
  def check(body)
    Dir.mktmpdir do |dir|
      fn = File.join(dir, 'YP30n0031.xml')
      File.write(fn, <<~XML)
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>#{body}</body></text></TEI>
      XML
      out, = capture_io { CBETA::P5aChecker.new.check_file(fn) }
      out
    end
  end

  def test_forced_lb_without_n_is_allowed
    out = check('<p><lb ed="YP" n="0013a02"/>a<lb type="forced"/>b</p>')
    assert_includes out, '未發現錯誤'
  end

  def test_lb_without_n_reports_e06
    out = check('<p><lb ed="YP"/>a</p>')
    assert_includes out, '[E06]'
  end
end
