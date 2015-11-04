# ruby-cbeta

Ruby gem for use CBETA resources

* Convert CBETA XML P5a to HTML
* Convert CBETA XML P5a to EPUB
* Convert CBETA XML P5a to Text
* Convert CBETA BM to Text
* Convert HTML to PDF

# Reqirements

## nokogiri

	gem install nokogiri

## EPUB

CBETA::P5aToEPUB need gepub 0.7.0beta3 or newer:

	gem install specific_install
	gem specific_install -l https://github.com/skoji/gepub.git

## PDF

install wicked_pdf

	gem install wicked_pdf

widked_pdf use wkhtmltopdf, download and install wkhtmltopdf 0.12.2.1 from http://wkhtmltopdf.org/downloads.html

Don't use wkhtmltopdf-binary gem 0.9.9.3, PDF file generated from it is not searchabel and not copyable.

# Getting Started

	gem install cbeta

# Examples

See folder examples/

# Documentation

[Documentation for cbeta on Rubydoc](http://www.rubydoc.info/gems/cbeta/)