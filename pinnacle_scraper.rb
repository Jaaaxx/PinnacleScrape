# frozen_string_literal: true

gem 'selenium-webdriver'
gem 'nokogiri'
require 'selenium-webdriver'
require 'nokogiri'
require 'json'
# Emulates rails' squish method
squish = ->(s) { s.strip.gsub(/\s+/, ' ') }
blank  = ->(s) { s.to_s.strip.empty? ? 'BLANK' : s }
# Configure the driver to run in headless mode
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
d = Selenium::WebDriver.for :chrome, options: options
d.get 'https://gb.browardschools.com/Pinnacle/Gradebook/InternetViewer/GradeReport.aspx'
# Login Page
(d.find_element :id, 'userNameInput').clear
(d.find_element :id, 'userNameInput').send_keys '0612002586'
(d.find_element :id, 'passwordInput').clear
(d.find_element :id, 'passwordInput').send_keys 'Jimmy_03222005-Tron'
(d.find_element :id, 'submitButton').click
# Page showing all course grades
rows = Nokogiri::HTML(d.page_source).css('#year2019').css('.row')
# Dictionary with courses as keys, links to courses as values
course_links = {}
# Each course has its own row
rows.each do |row|
  course = row.css '.course'
  teacher = row.css '.teacher'
  # Quarter Identifier (clickable letter next to course)
  row.css('.letter-container').each do |letter|
    # Does not search courses that have no grades
    next if blank.call(squish.call(letter.css('.percent').text)) == 'BLANK'

    # Label underneath letter that shows quarter
    quarter = letter.css '.letter-label'
    # Creates key to add to dictionary for course links
    key = squish.call(course.text) + '|' +
          squish.call(quarter.text).sub('Quarter', 'Quarter ') +
          '|' + squish.call(teacher.text)
    course_links[key] = letter['href']
  end
end

courses = []
course_links.each do |course, l|
  course_info = {}
  d.get "https://gb.browardschools.com/Pinnacle/Gradebook/InternetViewer/#{l}"
  page = Nokogiri::HTML(d.page_source).css '#ContentMain'
  # Keys to add to hashed course information
  course_info['Grade']   = squish.call(Nokogiri::HTML(d.page_source)
                                   .css('#ContentHeader').css('.percent').text)
  course_info['Course']  = course.split('|')[0]
  course_info['Quarter'] = course.split('|')[1]
  course_info['Teacher'] = course.split('|')[2]
  assignments = page.css '.assignment'
  # Array of all individual grades' information
  indiv_grades = []
  assignments.each do |a|
    assignment_info = {}
    assignment_info['Name'] = squish.call(a.css('.title').text)
    assignment_info['Points'] = blank.call(squish.call(a.css('.points').text))
    assignment_info['Max'] = squish.call(a.css('.max').text).tr('max', '')
    indiv_grades << assignment_info
  end
  # Adds array of grades information to course info
  course_info['Assignments'] = indiv_grades
  courses << course_info
end

File.open('temp.json', 'w') { |f| f.write(courses.to_json) }