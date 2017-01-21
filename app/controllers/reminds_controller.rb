require 'line/bot'

class RemindsController < ApplicationController
  include ActionView::Helpers::TextHelper
  before_action :set_group
  before_action :set_remind, only: [:show, :edit, :update, :destroy, :activate, :inactivate]
  before_action :set_gmap, only: [:show, :edit, :update]
  before_action :set_before, only: [:show, :edit, :activate]

  def new
    @remind = @group.reminds.new
    gon.autoComplete = true
    gon.lat = 35.6586488
    gon.lng = 139.6966408
    gon.create = true
    gon.remindType = 'Event'
  end

  def create
    @remind = @group.reminds.new(remind_params)
    @remind.type = params.require(type.downcase.to_sym).permit(:remind_type)[:remind_type]
    @remind.datetime = combine_datetime
    @remind.at = remind_at(@remind.datetime)
    if @remind.save
      flash[:success] = 'リマインドを作成しました。'
      redirect_to group_path(@group)
    else
      render 'new'
    end
  end

  def show
    if @remind.schedule?
      @candidates = @remind.candidates.order(:id)
      @users = @candidates.first.users
    end
  end

  def activate; @remind.activate! end
  def inactivate; @remind.inactivate! end

  def edit
    @date, @time = @remind.parse_datetime
    gon.autoComplete = true
    gon.remindType = @remind.type || 'Event'

    if @remind.schedule?
      @remind.candidate_body = @remind.candidates.inject('') do |body, c|
        body + c.title + "\n"
      end
    end
  end

  def update
    @remind.type = params.require(type.downcase.to_sym).permit(:remind_type)[:remind_type]
    @remind.datetime = combine_datetime
    @remind.at = remind_at(@remind.datetime)
    unless @remind.activated?
      @remind.activated = true
      # ここでアクティブ通知を行う
      text = truncate(@remind.body, length: 25) + "\n" + @remind.active_text
      client.push_message(@remind.group.source_id, {
        type: 'template',
        altText: text,
        template: {
          type: 'buttons',
          title: @remind.name,
          text: text,
          actions: @remind.active_actions
        }
      })
    end

    parse_candidates(@remind) if @remind.schedule?

    if @remind.update(remind_params)
      flash[:success] = 'リマインドを更新しました。'
      redirect_to remind_path(@remind)
    else
      render 'edit'
    end
  end

  def destroy; end

  private

  def set_gmap
    gon.lat = @remind.latitude || 35.6586488
    gon.lng = @remind.longitude || 139.6966408
  end

  def remind_at(datetime)
    before = params.require(type.downcase.to_sym).permit(:before)[:before].to_i
    datetime - before * 60
  end

  def set_before
    @remind.before = (@remind.datetime - @remind.at).to_i / 60
  end

  def set_remind
    @remind = remind_class.find_by(uid: params[:id]) || remind_class.find_by(id: params[:id])
  end

  def combine_datetime
    dt = params.require(type.downcase.to_sym).permit(:date, :time)
    "#{dt[:date]} #{dt[:time]}"
  end

  # Event or Schedule
  def type
    params[:type] || 'Remind'
  end

  def remind_params
    params.require(type.downcase.to_sym).permit(:name, :body, :scale, :place, :address, :longitude, :latitude)
  end

  # 中身を改行でパースして保存
  def parse_candidates(schedule)
    body = params.require(type.downcase.to_sym).permit(:candidate_body)
    body[:candidate_body].lines.each do |line|
      title = line.chomp
      next if title.size.zero?
      candidate = Candidate.find_or_initialize_by(title: title, schedule_id: schedule.id)
      candidate.title = title
      candidate.save
    end
  end

  def remind_class
    return Remind if type.blank?
    type.constantize
  end

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end
end
