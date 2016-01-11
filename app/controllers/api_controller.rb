class ApiController < ApplicationController
	skip_before_action :verify_authenticity_token
require "open-uri"
def generateSchedule(usid, days)
  	@daystoconsider = days

  	# @medsfordays will be the days that the medication is supposed to be taken, 100% adherence
	@medsfordays = {}

	b = 0
	@daystoconsider.times do
		b += 1
		@medsfordays[b] = []
	end

	# This calculates @medsfordays
	Medication.where(:userid => usid).each do |medication|
		frequency = medication.schedule
		timestamp = medication.created_at
		int = @daystoconsider + 1
		@daystoconsider.times do
			int -= 1
			datadate = Date.today + (int - 2).days
			createadate = Date.strptime("#{timestamp.month}/#{timestamp.day}/#{timestamp.year}", '%m/%d/%Y')
			dayssinceadd = datadate - createadate
			if dayssinceadd % 7 == 0
				weekly = true
			else
				weekly = false
			end

			if frequency == "daily" && createadate <= datadate
				@medsfordays[int].push medication.id
			elsif frequency == "weekly" && createadate <= datadate && weekly == true
				@medsfordays[int].push medication.id
			elsif frequency != "daily" && frequency != "weekly" && createadate <= datadate
				calcfreqone = frequency.split
				calcfreqtwo = calcfreqone[0].to_i
				calcfreqthree = calcfreqone[1].split("/")
				calcfreqfour = calcfreqthree[1]
				if calcfreqfour == "day" && createadate <= datadate
					calcfreqtwo.times do
						@medsfordays[int].push medication.id
					end
				end
				if calcfreqfour == "week" && createadate <= datadate
					@daystopushweek = []
					weektimeblock = 7.0 / calcfreqtwo
					g = 0
					calcfreqtwo.times do
						g += 1
						@daystopushweek.push (weektimeblock * g)
					end
					@daystopushweek.map! {|item| item.round}
					@daystopushweek.each do |numb|
						if (numb + createadate.strftime("%w").to_i) > 7
							newnumb = numb + createadate.strftime("%w").to_i - 7
						else
							newnumb = numb + createadate.strftime("%w").to_i
						end
						if datadate.strftime("%u").to_i == newnumb
							@medsfordays[int].push medication.id
						end
					end
				end
				if calcfreqfour == "month" && createadate <= datadate
					@daystopushmonth = []
					monthtimeblock = @daysinthismonth.to_f / calcfreqtwo
					g = 0
					calcfreqtwo.times do
						g += 1
						@daystopushmonth.push (monthtimeblock * g)
					end
					@daystopushmonth.map! {|item| item.round}
					@daystopushmonth.each do |numb|
						if datadate.day.to_i == numb
							@medsfordays[int].push medication.id
						end
					end
				end
			end
		end
	end

	return @medsfordays
end

def generatetimeline
	#use a parameter to get user id in the future
	@userident = 1

	@schedule = generateSchedule(@userident, 8)
	@timeline = {}

	@theuser = User.find(@userident)

	d = 0
	8.times do
		d += 1
		toDay = ""
		thisDate = Date.today + (d - 2).days
		if d == 1
			toDay = "Yesterday"
		elsif d == 2
			toDay = "Today"
		elsif d == 3
			toDay = "Tomorrow"
		else
			toDay = thisDate.strftime("%A")
		end

		todayMeds = []
		for x in @schedule[d]
			hasTaken = false
			thisMed = Medication.find(x)
			for g in thisMed.datapoints
				if g[0].to_date == thisDate && g[1] == "true"
					hasTaken = true
				end
			end
			todayMeds.append ["#{thisMed.name}, #{thisMed.dose}", hasTaken, thisMed.id]
		end

		@timeline[toDay] = todayMeds
	end


	#turn data into html
	@fullhtml = ""
	i = 0
	for day in @timeline
		i += 1
		if i % 3 == 0
			dotcolor = "dot blue"
		elsif i % 3 == 1
			dotcolor = "dot red"
		else
			dotcolor = "dot green"
		end
		dateblock = "
		<div class = 'dateblock'>
        <div class = '" + dotcolor + "'></div>
        <p id = 'datetitle'>#{day[0]}</p>
		"
		for k in day[1]
			if i < 3
			dateblock = dateblock + "
				<div class = 'medtakeblock'>
            		<p class = 'medname'>#{k[0]}#{k[1]}</p>
            		<div>
            			<span class = 'takeinfo' style = 'display: none;'>#{i - 2}, #{k[2]}</span>
                		<p>Take</p>
            		</div>
        		</div>
				"
			else
				dateblock = dateblock + "
				<div class = 'medtakeblock'>
            		<p class = 'medname'>#{k[0]}#{k[1]}</p>
        		</div>
				"
			end
		end
		if day[1] == []
			dateblock = dateblock + "
			<div class = 'medtakeblock'>
            	<p class = 'medname'>There aren't any medications on this day</p>
        	</div>"
		end
		@fullhtml = @fullhtml + dateblock + "</div>"
	end
	final = @fullhtml + '<br><br>'
	render :html => final.html_safe
end

def takemedicationapi
	#"0,7"
	expectedparam = params[:i]
	daysag = expectedparam.split(",")[0].to_i
	medid = expectedparam.split(",")[1].to_i
	med = Medication.find(medid)
	if med.datapoints.include? ["#{Date.today + daysag.to_i}", "true"]
	else
		med.datapoints.push ["#{Date.today + daysag.to_i}", "true"]
		med.save!
		render :text => ""
	end
end

def generatemeds
	userident = 1
	finalhtml = ""
	Medication.where(:userid => userident).each do |medication|
		finalhtml = finalhtml + "<div class = 'medicationbox mbox'>
			<span class = 'idtag' style = 'display: none;'>"+"#{medication.id}"+"</span>
            <p id = 'medtitlename'><span class = 'medactname'>#{medication.name}</span>, #{medication.dose}</p>
            <p id = 'medlasttaken'>Last Taken: YY:YYam</p>
            <p id = 'pillsreminderlabel'>x pills left</p>
            <img src = 'img/fwd_arrow.png' id = 'forwardmedarrow' style = 'margin-top: 18px;'>
        </div>"
	end
	render :html => finalhtml.html_safe
end

def generatenotes
	userident = 1
	finalhtml = ""
	d = 0
	Note.where(:userid => userident).each do |note|
		d += 1
		finalhtml = finalhtml + "<div class = 'medicationbox notebox'>
			<p id = 'medtitlename'><span class = 'medactname'>#{note.name}</span></p>
			<p id = 'medlasttaken'>Created: #{note.created_at.to_time.strftime('%x')}</p>
			<p id = 'pillsreminderlabel'>#{note.notecontent[0...15]}...</p>
			<img src = 'img/fwd_arrow.png' id = 'forwardmedarrow'>
		</div>"
	end
	(20 - (d * 0.66).ceil).times do
		finalhtml = finalhtml + "<div class = 'horizontalline'></div>"
	end
	render :html => finalhtml.html_safe
end


def createthedb
	if params[:term].length >= 3
    	arry = MedDb.search(params[:term])
 		meds = []
 		for g in arry
 			meds.append g.name
 		end
    	if meds.length > 2
    		meds.reject! {|x| x.length > 30}
    		sorted = meds.sort_by(&:length).first(5)
    		render :json => sorted
    	else
    		render :json => meds
    	end
	else
		render :json => []
	end
=begin
	string = "concert"
	letterscorrect = 0
	index = 0
	stop = false
	@dblength = [0, 24094]
	letters = []
	rendered = false
	i = 0
	while stop == false && i < 20
		i += 1
		middle = (@dblength[1] + @dblength[0]) / 2
		split = MedDb.find(middle).name.downcase
		if split.length > letterscorrect && string.length > letterscorrect
		if split[letterscorrect].ord > string[letterscorrect].ord && split[0, letterscorrect] == string[0, letterscorrect]
			@dblength = [@dblength[0], middle]
		elsif split[letterscorrect].ord < string[letterscorrect].ord && split[0, letterscorrect] == string[0, letterscorrect]
			@dblength = [middle, @dblength[1]]
		elsif split[letterscorrect].ord < string[letterscorrect].ord && split[letterscorrect - 1].ord < string[letterscorrect - 1].ord
			@dblength = [middle, @dblength[1]]
		elsif split[letterscorrect].ord < string[letterscorrect].ord && split[letterscorrect - 1].ord > string[letterscorrect - 1].ord
			@dblength = [@dblength[0], middle]
		elsif split[letterscorrect].ord > string[letterscorrect].ord && split[letterscorrect - 1].ord < string[letterscorrect - 1].ord
			@dblength = [middle, @dblength[1]]
		elsif split[letterscorrect].ord > string[letterscorrect].ord && split[letterscorrect - 1].ord > string[letterscorrect - 1].ord
			@dblength = [@dblength[0], middle]
		elsif split[letterscorrect].ord == string[letterscorrect].ord && split[0, letterscorrect] == string[0, letterscorrect]
			if letterscorrect < (string.length - 1)
				letterscorrect += 1
			else
				stop = true
			end
			letters.append split[letterscorrect - 1]
			if split[letterscorrect].ord > string[letterscorrect].ord
				@dblength = [@dblength[0], middle]
			elsif split[letterscorrect].ord < string[letterscorrect].ord
				@dblength = [middle, @dblength[1]]
			end
			if split == string
				stop = true
				render :text => "Medication found in #{i} moves."
				rendered = true
			else
				if (@dblength[1] - @dblength[0]) < 10
					for x in (@dblength[0] - 5 .. @dblength[1] + 5)
						if MedDb.find(x).name == string
							stop = true
							render :text => "Medication found in #{i} moves."
							rendered = true
						end
					end
				end
			end
		end
		end
	end
	if rendered == false && MedDb.where(:name => string).empty?
		render :text => "Medication not found."
	else
		if rendered == false
			render :text => "Medication found in failed moves. #{@dblength} #{letters} #{letterscorrect}"
		end
	end
=end
end

def createmedication
	if params[:toggle] == "on"
		@med = Medication.new(:userid => 1, :name => params[:medname], :schedule => "#{params[:times]} times/#{params[:timeunit]}", :dose => "#{params[:dosenum]}#{params[:doseun]}", :notification_time => "#{params[:taketime]}")
	else
		@med = Medication.new(:userid => 1, :name => params[:medname], :schedule => "daily", :dose => "#{params[:dosenum]}#{params[:doseun]}")
	end
	@med.save
	render :text => "success"
end

def deletemedapi
	if params[:med].present?
		Medication.destroy(params[:med])
		render :text => ""
	end
end

def getnoteinfo
	@note = Note.find(params[:id])
	render :json => [@note.name, @note.notecontent]
end

def registerdevice
	@user = User.find(params[:id])
	if @user.deviceids.include? params[:devid]
		render :text => @user.deviceids
	else
		@user.deviceids.push params[:devid]
		@user.save!
		render :text => "sweet"
	end
end

def sendnotification
	@u = User.find(1).deviceids
	for e in @u
		APNS.send_notification(e, :alert => "You have 2 medications to take.", :message => "hello")
	end
	render :text => " "
end

#class end
end




























