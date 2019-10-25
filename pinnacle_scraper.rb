# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

get '/' do
  'Pinnacle Web Scraper'
end

get '/api' do
  agent = Mechanize.new
  page = agent.get('https://fs.browardschools.com/adfs/ls/?wctx=WsFedOwinState%3dnZZ1ZykbSO8be-K298TNbJe1xdfUs01zuVyG-22YuP6OpgjA825E-cleXlE_x7upfBuMup-eKNPk38DTuJN7SO5zj2g3bVxqq93jWmG7UWzER2CPcHAM4O5GCuJ8RSar7-lPywjTxVvUc-5lgkBEnQvVwnUbbEJC9LBe7XpPogfjZqnCw8jcVfT27IUE59XO4Fv6PNytNc3-5v5bTzRW8i_hzgj7_fd6iVPNrkZlZjvdIN8V0ScNd3z8DWNhYDYNxyrukVDu4NUxo7y6R2xe6fu4gEk-8A80lsdYGkdA4zCp7VMnjzpv6UX9scC_zOc4PmBSRg&wa=wsignin1.0&wtrealm=http%3a%2f%2fgb.browardschools.com%2fpinnacle%2fgradebook%2f')
  form = page.forms.first
  form['UserName'] = 'browardschools\\' + params['un'].to_s
  form['Password'] = params['pw'].to_s
  page = form.submit.forms.first.submit
  squish = ->(s) { s.strip.gsub(/\s+/, ' ') }
  blank  = ->(s) { s.to_s.strip.empty? ? 'BLANK' : s }
  if params['un'].to_s.downcase[0] == 'p'
    teacher_info = {}
    teacher_info['Name'] = Nokogiri::HTML(page.body).css('#HeaderRow').css('.hidden-xs').text
    teacher_info.to_json == '{"Name":""}' ? 'Username or Password was Incorrect' : teacher_info.to_json
  else
    rows = Nokogiri::HTML(page.body).css('#year2019').css('.row')
    course_links = {}
    rows.each do |row|
      course = row.css '.course'
      teacher = row.css '.teacher'
      row.css('.letter-container').each do |letter|
        quarter = letter.css '.letter-label'
        if squish.call(quarter.text).sub('Quarter', 'Quarter ') == 'Quarter 1'
          key = squish.call(course.text) + '|' + squish.call(quarter.text).sub('Quarter', 'Quarter ') + '|' + squish.call(teacher.text)
          course_links[key] = letter['href']
        end
      end
    end
    courses = []
    threading = []
    course_links.each_with_index do |(course, l), index|
      threading << Thread.new do
      course_info = {}
      g_driver = agent.get("https://gb.browardschools.com/Pinnacle/Gradebook/InternetViewer/#{l}")
      page = Nokogiri::HTML(g_driver.body).css '#ContentMain'
      course_info['Grade'] = squish.call(Nokogiri::HTML(g_driver.body).css('#ContentHeader').css('.percent').text.tr('%', ''))
      course_info['Course'] = course.split('|')[0]
      course_info['Quarter'] = course.split('|')[1]
      course_info['Teacher'] = course.split('|')[2]
      assignments = page.css '.assignment'
      indiv_grades = []
      assignments.each do |a|
        assignment_info = {}
        assignment_info['Name'] = squish.call(a.css('.title').text)
        assignment_info['Points'] = blank.call(squish.call(a.css('.points').text))
        assignment_info['Max'] = squish.call(a.css('.max').text).tr('max ', '')
        indiv_grades << assignment_info
      end
      course_info['Assignments'] = indiv_grades
      courses[index] = course_info
      end
    end
    threading.each(&:join)
    courses.to_json == '[]' ? 'Username or Password was Incorrect' : courses.to_json
  end
end



get '/verify' do
  agent = Mechanize.new
  page = agent.get('https://fs.browardschools.com/adfs/ls/?wctx=WsFedOwinState%3dnZZ1ZykbSO8be-K298TNbJe1xdfUs01zuVyG-22YuP6OpgjA825E-cleXlE_x7upfBuMup-eKNPk38DTuJN7SO5zj2g3bVxqq93jWmG7UWzER2CPcHAM4O5GCuJ8RSar7-lPywjTxVvUc-5lgkBEnQvVwnUbbEJC9LBe7XpPogfjZqnCw8jcVfT27IUE59XO4Fv6PNytNc3-5v5bTzRW8i_hzgj7_fd6iVPNrkZlZjvdIN8V0ScNd3z8DWNhYDYNxyrukVDu4NUxo7y6R2xe6fu4gEk-8A80lsdYGkdA4zCp7VMnjzpv6UX9scC_zOc4PmBSRg&wa=wsignin1.0&wtrealm=http%3a%2f%2fgb.browardschools.com%2fpinnacle%2fgradebook%2f')
  form = page.forms.first
  form['UserName'] = 'browardschools\\' + params['un'].to_s
  form['Password'] = params['pw'].to_s
  page = agent.post(page.uri.to_s, form.request_data)
  Nokogiri::HTML(page.body).at_css('#errorText') ? 'False' : 'True'
end
