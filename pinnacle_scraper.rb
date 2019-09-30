# frozen_string_literal: true
MALLOC_ARENA_MAX = 1


require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

configure :production do
  enable :reloader
end

def selenium_scrape(username, password)
  # Configure the driver to run in headless mode
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary(ENV['GOOGLE_CHROME_BIN'])
  options.add_argument('--no-sandbox')
  options.add_argument('--headless')
  options.add_argument('--disable-dev-shm-usage')
  d = Selenium::WebDriver.for :chrome, options: options

  @username = username
  @password = password

  # Emulates rails' squish method
  squish = ->(s) { s.strip.gsub(/\s+/, ' ') }
  blank  = ->(s) { s.to_s.strip.empty? ? 'BLANK' : s }
  d.get 'https://gb.browardschools.com/Pinnacle/Gradebook/InternetViewer/GradeReport.aspx'
  # Login Page
  (d.find_element :id, 'userNameInput').clear
  (d.find_element :id, 'userNameInput').send_keys @username
  (d.find_element :id, 'passwordInput').clear
  (d.find_element :id, 'passwordInput').send_keys @password
  (d.find_element :id, 'submitButton').click
  if Nokogiri::HTML(d.page_source).css('#errorText').text != ''
    'Username or Password was incorrect'
  else
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
        key = squish.call(course.text) + '|' + squish.call(quarter.text).sub('Quarter', 'Quarter ') + '|' + squish.call(teacher.text)
        course_links[key] = letter['href']
      end
    end

    courses = []
    course_links.each do |course, l|
      course_info = {}
      d.get "https://gb.browardschools.com/Pinnacle/Gradebook/InternetViewer/#{l}"
      page = Nokogiri::HTML(d.page_source).css '#ContentMain'
      # Keys to add to hashed course information
      course_info['Grade']   = squish.call(Nokogiri::HTML(d.page_source).css('#ContentHeader').css('.percent').text)
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
    # Renders JSON to page
    courses.to_json
  end
end

def verify_pw(username, password)
  Selenium::WebDriver::Chrome.driver_path = ENV['GOOGLE_CHROME_BIN']
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary(ENV['GOOGLE_CHROME_BIN'])
  options.add_argument('--no-sandbox')
  options.add_argument('--headless')
  options.add_argument('--disable-dev-shm-usage')
  d = Selenium::WebDriver.for :chrome, options: options
  @username = username
  @password = password
  d.get 'https://gb.browardschools.com/Pinnacle/Gradebook/InternetViewer/GradeReport.aspx'
  # Login Page
  (d.find_element :id, 'userNameInput').clear
  (d.find_element :id, 'userNameInput').send_keys @username
  (d.find_element :id, 'passwordInput').clear
  (d.find_element :id, 'passwordInput').send_keys @password
  (d.find_element :id, 'submitButton').click
  if Nokogiri::HTML(d.page_source).css('#errorText').text != ''
    'False'
  else
    'True'
  end
end

get '/' do
  'Pinnacle Web Scraper'
end

get '/verify' do
  verify_pw(params['un'].to_s, params['pw'].to_s)
end

get '/api' do
  selenium_scrape(params['un'].to_s, params['pw'].to_s)
end
