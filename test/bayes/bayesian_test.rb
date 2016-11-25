# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
class BayesianTest < Test::Unit::TestCase
  def setup
    @classifier = ClassifierReborn::Bayes.new('Interesting', 'Uninteresting', language: 'en-ja')
  end

  def test_good_training
    assert_nothing_raised { @classifier.train_interesting 'love' }
  end

  def test_training_with_utf8
    assert_nothing_raised { @classifier.train_interesting 'Água' }
  end

  def test_stemming_enabled_by_default
    assert @classifier.stemmer_enabled?
  end

  def test_bad_training
    assert_raise(StandardError) { @classifier.train_no_category 'words' }
  end

  def test_bad_method
    assert_raise(NoMethodError) { @classifier.forget_everything_you_know '' }
  end

  def test_categories
    assert_equal %w(Interesting Uninteresting).sort, @classifier.categories.sort
  end

  def test_categories_from_array
    another_classifier = ClassifierReborn::Bayes.new %w(Interesting Uninteresting)
    assert_equal another_classifier.categories.sort, @classifier.categories.sort
  end

  def test_add_category
    @classifier.add_category 'Test'
    assert_equal %w(Test Interesting Uninteresting).sort, @classifier.categories.sort
  end

  def test_dynamic_category_succeeds_with_auto_categorize
    classifier = ClassifierReborn::Bayes.new 'Interesting', 'Uninteresting', auto_categorize: true
    classifier.train('Ruby', 'I really sweet language')
    assert classifier.categories.include?('Ruby')
  end

  def test_dynamic_category_fails_without_auto_categorize
    assert_raises(ClassifierReborn::Bayes::CategoryNotFoundError) do
      @classifier.train('Ruby', 'A really sweet language')
    end
    refute @classifier.categories.include?('Ruby')
  end

  def test_classification
    @classifier.train_interesting 'here are some good words. I hope you love them'
    @classifier.train_uninteresting 'here are some bad words, I hate you'
    assert_equal 'Uninteresting', @classifier.classify('I hate bad words and you')
  end

  def test_classification_with_threshold
    b = ClassifierReborn::Bayes.new 'Digit'
    assert_equal 1, b.categories.size

    refute b.threshold_enabled?
    b.enable_threshold
    assert b.threshold_enabled?
    assert_equal 0.0, b.threshold # default

    b.threshold = -7.0

    10.times do |a_number|
      b.train_digit(a_number.to_s)
      b.train_digit(a_number.to_s)
    end

    10.times do |a_number|
      assert_equal 'Digit', b.classify(a_number.to_s)
    end

    refute b.classify('xyzzy')
  end

  def test_classification_with_threshold_again
    b = ClassifierReborn::Bayes.new 'Normal'
    assert_equal 1, b.categories.size

    refute b.threshold_enabled?
    b.enable_threshold
    assert b.threshold_enabled?
    assert_equal 0.0, b.threshold # default

    %w(
      http://example.com/about
      http://example.com/contact
      http://example.com/download
      http://example.com/login
      http://example.com/logout
      http://example.com/blog/2015-04-01
    ).each do |url|
      b.train_normal(url)
    end

    assert 'Normal', b.classify('http://example.com')
    refute b.classify("http://example.com/login/?user='select * from users;'")
  end

  def test_classification_with_score
    @classifier.train_interesting 'here are some good words. I hope you love them'
    @classifier.train_uninteresting 'here are some bad words, I hate you'
    assert_in_delta(-4.85, @classifier.classify_with_score('I hate bad words and you')[1], 0.1)
  end

  def test_untrain
    @classifier.train_interesting 'here are some good words. I hope you love them'
    @classifier.train_uninteresting 'here are some bad words, I hate you'
    @classifier.add_category 'colors'
    @classifier.train_colors 'red orange green blue seven'
    classification_of_bad_data = @classifier.classify 'seven'
    @classifier.untrain_colors 'seven'
    classification_after_untrain = @classifier.classify 'seven'
    assert_not_equal classification_of_bad_data, classification_after_untrain
  end

  def test_serialize_safe_in_en
    @classifier = ClassifierReborn::Bayes.new('Interesting', 'Uninteresting', language: 'en')
    
    @classifier.train_interesting "here are some good words. I hope you love them"
    @classifier.train_uninteresting "here are some bad words, I hate you"
    assert_equal 'Uninteresting', @classifier.classify("I hate bad words and you")
    assert_equal 'Interesting', @classifier.classify("I love")

    classifier_snapshot = Marshal.dump @classifier
    trained_classifier = Marshal.load classifier_snapshot
    
    assert_equal 'Uninteresting', trained_classifier.classify("I hate bad words and you")
    assert_equal 'Interesting', trained_classifier.classify("I love")
  end


  def test_example
    @classifier.train_interesting "here are some good words. I hope you love them"
    @classifier.train_uninteresting "here are some bad words, I hate you"
    assert_equal 'Uninteresting', @classifier.classify("I hate bad words and you")
    assert_equal 'Interesting', @classifier.classify("I love")

    classifier_snapshot_yaml = @classifier.save_to_yaml
    trained_classifier = ClassifierReborn::Bayes.new('Interesting', 'Uninteresting', language: 'en-ja')
    trained_classifier.load_yaml(classifier_snapshot_yaml)
    
    assert_equal 'Uninteresting', trained_classifier.classify("I hate bad words and you")
    assert_equal 'Interesting', trained_classifier.classify("I love")
  end

  def test_save_and_load
    correct_yaml = "---\n- :Interesting: {}\n  :Uninteresting: {}\n- 0\n- {}\n- {}\n- en-ja\n- false\n- false\n- 0.0\n- true\n- true\n"
    
    yaml = @classifier.save_to_yaml
    assert_equal correct_yaml, yaml
    
    @classifier.load_yaml(yaml)
    loaded_yaml = @classifier.save_to_yaml
    assert_equal correct_yaml, loaded_yaml
  end

  def test_multiple_languages
    @classifier.train_interesting "ここにいい単語があります。私はあなたがそれらを愛することを望みます。 here are some good words. I hope you love them"
    @classifier.train_uninteresting "ここに悪い単語があります。私はあなたが嫌いです。 here are some bad words, I hate you"
    assert_equal 'Uninteresting', @classifier.classify("I hate bad words and you")
    assert_equal 'Uninteresting', @classifier.classify("私は単語とあなたが嫌いです。")
    assert_equal 'Interesting', @classifier.classify("I love")
    assert_equal 'Interesting', @classifier.classify("私は愛します。")

    classifier_snapshot_yaml = @classifier.save_to_yaml
    trained_classifier = ClassifierReborn::Bayes.new('Interesting', 'Uninteresting', language: 'en-ja')
    trained_classifier.load_yaml(classifier_snapshot_yaml)

    assert_equal 'Uninteresting', trained_classifier.classify("I hate bad words and you")
    assert_equal 'Uninteresting', trained_classifier.classify("私は単語とあなたが嫌いです。")
    assert_equal 'Interesting', trained_classifier.classify("I love")
    assert_equal 'Interesting', trained_classifier.classify("私は愛します。")
  end
end
