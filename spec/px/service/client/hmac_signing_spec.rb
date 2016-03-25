require 'spec_helper'

describe Px::Service::Client::HmacSigning do
  subject {
    Px::Service::Client::Base.tap do |c|
      c.include(Px::Service::Client::HmacSigning)
    end.new
  }

  describe '#make_request' do
    context "when the underlying request method succeeds" do
      let(:url) { 'http://localhost:3000/path' }      

      let(:resp) { subject.send(:make_request, 'get', url) }
      let(:headers) { resp.request.options[:headers] }

      it "returns a Future" do
        expect(resp).to be_a_kind_of(Px::Service::Client::RetriableResponseFuture)
      end

      it "contains a header with signature" do
        expect(headers).to have_key("Signature")
      end

      it "contains a header with nonce" do
        expect(headers).to have_key("Nonce")
      end

      it "contains a header with timestamp" do
        expect(headers).to have_key("Timestamp")
      end
    end
  end
end