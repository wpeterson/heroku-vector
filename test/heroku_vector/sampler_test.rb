require File.absolute_path File.dirname(__FILE__) + '/../test_helper'

describe HerokuVector::Sampler do
  describe '#initialize' do
    let(:capacity) { 10 }
    let(:sampler) { HerokuVector::Sampler.new(capacity) }

    it 'should set capacity' do
      assert_equal capacity, sampler.capacity
    end

    it 'should initialize data container' do
      assert_equal [], sampler.data
    end
  end

  describe '#push' do
    let(:sampler) { HerokuVector::Sampler.new(10) }

    it 'should append item to data' do
      assert_equal [], sampler.data
      
      sampler.push 1
      assert_equal [1], sampler.data

      sampler.push 2
      assert_equal [1, 2], sampler.data
    end

    it 'should cap capacity' do
      (1..10).each {|i| sampler << i }
      assert_equal (1..10).to_a, sampler.data

      sampler << 11
      assert_equal (2..11).to_a, sampler.data
    end

    it 'should alias << to push' do
      assert_equal [], sampler.data
      
      sampler << 1
      assert_equal [1], sampler.data
    end
  end

  describe '#mean' do
    let(:sampler) { HerokuVector::Sampler.new(10) }

    it 'should handle empty data' do
      assert_equal 0.0, sampler.mean
    end

    it 'should calculate mean value' do
      sampler << 1
      assert_equal 1.0, sampler.mean

      (2..4).each {|i| sampler << i }
      assert_equal 2.5, sampler.mean
    end
  end
end