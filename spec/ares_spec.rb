# frozen_string_literal: true

RSpec.describe 'Ares::Runtime' do
  it 'has a version number' do
    expect(Ares::Runtime::VERSION).not_to be_nil
  end

  it 'can initialize a Router' do
    expect(Ares::Runtime::Router.new).to be_a(Ares::Runtime::Router)
  end
end
