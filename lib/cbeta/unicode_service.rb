# 判斷字元收錄於哪一版 Unicode
#
# 使用 Ruby 內建 regexp 的 Unicode Age 屬性（\p{Age=...}）判斷。
# Age 屬性一經指定就不會變動，所以結果不受 Ruby 版本影響。
class CBETA::UnicodeService
  # Unicode 3.0 以內
  LEVEL1 = /\A\p{Age=3.0}+\z/

  # Unicode 10.0 以內
  LEVEL2 = /\A\p{Age=10.0}+\z/

  # Unicode 3.0 以內 在 mobile 可以正確顯示
  #
  # @param code [String] 字元
  # @return [Boolean]
  def level1?(code)
    return false if code.nil?
    LEVEL1.match?(code)
  end

  # Unicode 10 以內 在 desktop 有字型可以顯示
  #
  # @param code [String] 字元
  # @return [Boolean]
  def level2?(code)
    return false if code.nil?
    LEVEL2.match?(code)
  end
end
