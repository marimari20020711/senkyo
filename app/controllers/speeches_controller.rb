class SpeechesController < ApplicationController
  def index
    @q = Speech.ransack(params[:q])
    @speeches = @q.result.includes(:politician).order(date: :desc).limit(20)
  end
end
