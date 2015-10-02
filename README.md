# ruby-cbeta

Ruby gem for use CBETA resources

* CBETA XML P5a 轉為 HTML
* CBETA XML P5a 轉為 EPUB
* CBETA XML P5a 轉為 純文字
* CBETA BM 轉 純文字

# Reqirements

讀取 XML 的各種功能需要 XML parser nokogiri:

	gem install nokogiri

如果要使用 P5aToEPUB，需要從 GitHub 安裝 gepub 0.7.0beta3 以上(含)的版本：

	gem install specific_install
	gem specific_install -l https://github.com/skoji/gepub.git

# Getting Started

	gem install cbeta

# Examples

See folder examples/

# Documentation

[Documentation for cbeta on Rubydoc](http://www.rubydoc.info/gems/cbeta/)