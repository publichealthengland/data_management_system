require 'test_helper'

class ColorectalMainlineImporterTest < ActiveSupport::TestCase
  test 'ensure load creates expected records and logging' do
    e_batch  = e_batch(:colorectal_batch)
    filename = SafePath.new('test_files', e_batch.original_filename)
    importer = Import::Colorectal::Core::ColorectalMainlineImporter.new(filename, e_batch)
    assert_difference('Pseudo::GeneticTestResult.count', + 2) do
      assert_difference('Pseudo::GeneticSequenceVariant.count', + 1) do
        @importer_stdout, @importer_stderr = capture_io do
          importer.load
        end
      end
    end

    assert @importer_stderr.blank?
    logs = @importer_stdout.split("\n")

    expected_logs = [
      '(WARN) Cannot extract exon from: NP_000240.1:p.(Glu23LysfsTer13)',
      '(ERROR) Input: 0 given for variant class of impropertype (Integer), or out of range',
      '(WARN) Genomic change did not match expected format,adding raw: NC_000003.11:',
      '(WARN) Cannot extract exon from: NP_000240.1:',
      '(INFO) Num genes failed to parse: 0 of 2 tests being attempted',
      '(INFO) Num genes successfully parsed: 2 of2 attempted',
      '(INFO) Num genocolorectals failed to parse: 1of 2 attempted',
      '(INFO) Num positive tests: 1of 2 attempted',
      '(INFO) Num negative tests: 1of 2 attempted',
      '(INFO) Filter rejected 0 of2 genotypes seen',
      '(INFO) Num patients: 2',
      '(INFO) Num genetic tests: 2',
      '(INFO) Num test results: 2',
      '(INFO) Num sequence variants: 2',
      '(INFO) Num true variants: 1',
      '(INFO) Num duplicates encountered: ',
      '(INFO) Finished saving records to db'
    ]

    expected_logs.each { |expected_log| assert_includes(logs, expected_log) }

    positive_test = Pseudo::GeneticTestResult.find_by(teststatus: 1)
    assert_equal '1432', positive_test.gene
    assert positive_test.genetic_sequence_variants.count.zero?

    negative_test = Pseudo::GeneticTestResult.find_by(teststatus: 2)
    assert_equal '2744', negative_test.gene
    assert negative_test.genetic_sequence_variants.one?
    variant = negative_test.genetic_sequence_variants.first
    assert_equal 'c.67del', variant.codingdnasequencechange
    assert_equal 'p.Glu23LysfsTer13', variant.proteinimpact
    assert_equal 5, variant.variantpathclass
    assert_equal 3, variant.sequencevarianttype
  end
end
