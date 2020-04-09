# frozen_string_literal: true

require 'roda'

class App < Roda
  plugin :json

  plugin :padrino_render, engine: 'slim', views: 'www/templates', layout: 'layouts/application', cache: false

  route do |r|
    r.get '' do
      render 'index'
    end

    r.on 'api' do
      r.get 'inputs' do
        LuxListener.inputs
      end

      r.get 'registers' do
        LuxListener.registers
      end
    end
  end
end
