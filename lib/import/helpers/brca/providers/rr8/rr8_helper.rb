module Import
  module Helpers
    module Brca
      module Providers
        module Rr8
          module Rr8Helper
            include Import::Helpers::Brca::Providers::Rr8::Rr8Constants
            include Import::Helpers::Brca::Providers::Rr8::Rr8ReportCases

            def process_brca_palb2_diag_screening_failed_record
              reported_genes = %w[BRCA1 BRCA2 PALB2]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(9)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_brca_diag_class4_5_mlpa_record
              exon_variant = @report_string.match(EXON_LOCATION)
              positive_gene   = [exon_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              extract_exon_variant(positive_gene, exon_variant)
            end

            def process_brca_palb2_mlpa_class4_5_record
              return if @report_string.match(PREDICTIVE_POSITIVE_EXON).nil?

              exon_variant = @report_string.match(PREDICTIVE_POSITIVE_EXON)
              positive_gene = [exon_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes_w_palb2(positive_gene)
              end
              extract_exon_variant(positive_gene, exon_variant)
              @genotypes
            end

            def process_brca_palb2_diag_class4_5_record
              return if @report_string.match(CDNA_MUTATION_TYPES_REGEX).nil?
              cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
              positive_gene = [cdna_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes_w_palb2(positive_gene)
              end
              extract_cdna_variant_information(positive_gene, cdna_variant)
            end

            def process_predictive_b2_pathological_neg_record
              @genotype.add_gene('BRCA2')
              @genotype.add_status(1)
              @genotypes.append(@genotype)
            end

            def process_ngs_screening_failed_record
              reported_genes = %w[BRCA1 BRCA2]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(9)
                @genotypes.append(genotype2)
              end
            end

            def process_brca_diagnostic_class3_record
              return if @report_string.match(CDNA_MUTATION_TYPES_REGEX).nil?

              cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
              positive_gene = [cdna_variant[:brca]]
              @genotype.add_variant_class('unknown')
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              extract_cdna_variant_information(positive_gene, cdna_variant)
            end

            def process_brca_diagnostic_class4_5_record
              return if @report_string.match(CDNA_MUTATION_TYPES_REGEX).nil?

              cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
              positive_gene = [cdna_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              extract_cdna_variant_information(positive_gene, cdna_variant)
            end

            def process_generic_normal_record
              reported_genes = %w[BRCA1 BRCA2 PALB2 TP53]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(1)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_mlpa_only_fail_record
              reported_genes = %w[BRCA1 BRCA2]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(9)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_brca_palb2_diagnostic_class3_record
              cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
              positive_gene = [cdna_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes_w_palb2(positive_gene)
              end
              @genotype.add_variant_class('unknown')
              extract_cdna_variant_information(positive_gene, cdna_variant)
              @genotypes
            end

            def process_brca2_class3_unknown_variant_records
              cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
              positive_gene = [cdna_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              @genotype.add_variant_class('unknown')
              extract_cdna_variant_information(positive_gene, cdna_variant)
              @genotypes
            end

            def process_ngs_brca2_multiple_exon_mlpa_positive?
              positive_gene = [DEPRECATED_BRCA_NAMES_MAP[
                                @genotype_string.scan(DEPRECATED_BRCA_NAMES_REGEX).join
                                ]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              exon_variant = @report_string.match(EXON_LOCATION_EXCEPTIONS)
              extract_exon_variant(positive_gene, exon_variant)
            end

            def process_brca_palb2_diag_normal_record
              reported_genes = %w[BRCA1 BRCA2 PALB2]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(1)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_pred_class4_positive_records
              cdna_variant = @report_string.match(CDNA_VARIANT_CLASS_REGEX)
              positive_gene = [cdna_variant[:brca]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              @genotype.add_variant_class('likely pathogenic')
              extract_cdna_variant_information(positive_gene, cdna_variant)
              @genotypes
            end

            def process_class_3_unaffected_records
              cdna_variant = @report_string.match(CDNA_VARIANT_CLASS_REGEX)
              positive_gene = [cdna_variant[:brca]]

              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              @genotype.add_variant_class('unknown')
              extract_cdna_variant_information(positive_gene, cdna_variant)
              @genotypes
            end

            def process_brca_diagnostic_tests
              if  @report_string.scan(CDNA_VARIANT_CLASS_REGEX).size.positive?
                cdna_variant = @report_string.match(CDNA_VARIANT_CLASS_REGEX)
                positive_gene = [cdna_variant[:brca]]
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                extract_cdna_variant_information(positive_gene, cdna_variant)
              elsif @report_string.scan(/No pathogenic variant was identified/).size.positive?
                brca_double_negative
              end
              @genotypes
            end

            def process_screening_failed_records
              reported_genes = %w[BRCA1 BRCA2]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(9)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_predictive_test_exon13
              @genotype.add_gene('BRCA1')
              if @genotype_string.match(/Predictive Ex13 dup (?<negpos>neg|pos)/i)[:negpos] == 'pos'
                @genotype.add_variant_type('duplication')
                @genotype.add_exon_location('13')
                @genotype.add_status(2)
              else
                @genotype.add_status(1)
              end
              @genotypes.append(@genotype)
              @genotypes
            end

            def process_b1_mlpa_exon_positive
              positive_gene = [DEPRECATED_BRCA_NAMES_MAP[
                                @genotype_string.scan(DEPRECATED_BRCA_NAMES_REGEX).join
                                ]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              @genotype.add_gene(positive_gene.join)
              exon_variant = @report_string.match(EXON_LOCATION_EXCEPTIONS)
              extract_exon_variant(positive_gene, exon_variant)
            end

            def process_class4_pred_neg_record
              @genotype.add_gene(@report_string.match(BRCA_REGEX)[:brca])
              @genotype.add_status(1)
              @genotypes.append(@genotype)
            end

            def process_brca2_pttshift_records
              positive_gene = [DEPRECATED_BRCA_NAMES_MAP[
                                @genotype_string.scan(DEPRECATED_BRCA_NAMES_REGEX).join
                                ]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              if @report_string.scan(CDNA_MUTATION_TYPES_REGEX).size.positive?
                cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
                extract_cdna_variant_information(positive_gene, cdna_variant)
              else binding.pry
              end
              @genotypes
            end

            def process_familial_class_tests
              positive_gene = @report_string.scan(Import::Brca::Core::GenotypeBrca::BRCA_REGEX).
                              flatten.compact.uniq
              @genotype.add_gene(positive_gene.join)
              if @genotype_string.scan(/pos/i).size.positive?
                @genotype.add_variant_class(@genotype_string.scan(/[0-9]/i).join.to_i)
                if @report_string.scan(CDNA_VARIANT_CLASS_REGEX).size.positive?
                  cdna_variant = @report_string.match(CDNA_VARIANT_CLASS_REGEX)
                  extract_cdna_variant_information(positive_gene, cdna_variant)
                elsif @report_string.scan(CDNA_MUTATION_TYPES_REGEX).size.positive?
                  cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
                  extract_cdna_variant_information(positive_gene, cdna_variant)
                end
              elsif @genotype_string.scan(/neg/i).size.positive?
                @genotype.add_gene(@report_string)
                @genotype.add_status(1)
                @genotypes.append(@genotype)
              end
              @genotypes
            end

            def process_word_report_tests
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                reported_genes = %w[BRCA1 BRCA2]
                reported_genes.each do |negative_gene|
                  genotype2 = @genotype.dup
                  genotype2.add_gene(negative_gene)
                  genotype2.add_status(4)
                  @genotypes.append(genotype2)
                end
                @genotypes
              else
                @genotype.add_status(4)
                @genotypes.append(@genotype)
              end
              @genotypes
            end

            # TODO: implement 'else' cases
            def process_class_m_tests
              positive_gene   = [DEPRECATED_BRCA_NAMES_MAP[
                                @genotype_string.scan(DEPRECATED_BRCA_NAMES_REGEX).join
                                ]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              @genotype.add_gene(positive_gene.join)
              if @report_string.scan(CDNA_REGEX).size.positive?
                @genotype.add_gene_location(@report_string.match(CDNA_REGEX)[:location])
                if @report_string.scan(PROTEIN_REGEX).size.positive?
                  @genotype.add_protein_impact(@report_string.match(PROTEIN_REGEX)[:impact])
                end
                @genotypes.append(@genotype)
                # else binding.pry ONLY THREE CASES TO SORT OUT
              end
            end

            def process_truncating_variant_test
              positive_gene   = [DEPRECATED_BRCA_NAMES_MAP[
                                @genotype_string.scan(DEPRECATED_BRCA_NAMES_REGEX).join
                                ]]
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              @genotype.add_gene(positive_gene.join)
              if @report_string.scan(CDNA_MUTATION_TYPES_REGEX).size.positive?
                cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
                extract_cdna_variant_information(positive_gene, cdna_variant)
              elsif @report_string.scan(CDNA_REGEX).size.positive?
                cdnas = @report_string.scan(CDNA_REGEX).flatten.compact.uniq
                cdnas.each do |cdna|
                  mutant_genotype = @genotype.dup
                  mutant_genotype.add_gene_location(cdna)
                  mutant_genotype.add_status(2)
                  @genotypes.append(mutant_genotype)
                end
                @genotypes
              end
            end

            def process_double_normal_mlpa_test
              if @report_string.scan(SEQUENCE_ANALYSIS_SCREENING_MLPA).size.positive?
                brca_double_negative
                if @report_string.match(MLPA_FAIL_REGEX)
                  genotype3 = @genotype.dup
                  genotype3.add_gene($LAST_MATCH_INFO[:brca])
                  genotype3.add_method('mlpa')
                  genotype3.add_status(9)
                  @genotypes.append(genotype3)
                end
                @genotypes
              end
              @genotypes
            end

            def process_ashkenazi_tests
              if @genotype_string.scan(AJPOSITIVE_REGEX).size.positive?
                if @report_string.scan(CDNA_MUTATION_TYPES_REGEX).size.positive?
                  cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
                  positive_gene = [cdna_variant[:brca]]
                  extract_cdna_variant_information(positive_gene, cdna_variant)
                end
                @genotypes
              elsif @genotype_string.scan(AJNEGATIVE_REGEX).size.positive?
                @genotype.add_gene(@report_string.match(CDNA_MUTATION_TYPES_REGEX)[:brca])
                @genotype.add_status(1)
                @genotypes.append(@genotype)
              end
              @genotypes
            end

            # TODO: find more exceptions
            def process_confirmation_test
              confirmation_test_details = @genotype_string.match(CONFIRMATION_REGEX)
              case confirmation_test_details[:status]
              when 'neg'
                @genotype.add_gene(confirmation_test_details[:brca].to_i)
                @genotype.add_status(1)
                @genotypes.append(@genotype)
              when 'pos'
                if @report_string.scan(PREDICTIVE_REPORT_REGEX_POSITIVE).size.positive?
                  cdna_variant = @report_string.match(PREDICTIVE_REPORT_REGEX_POSITIVE)
                  positive_gene = [cdna_variant[:brca]]
                  extract_cdna_variant_information(positive_gene, cdna_variant)
                elsif @report_string.scan(PREDICTIVE_POSITIVE_EXON).size.positive?
                  exon_variant = @report_string.match(PREDICTIVE_POSITIVE_EXON)
                  positive_gene = [exon_variant[:brca]]
                  extract_exon_variant(positive_gene, exon_variant)
                elsif @report_string.scan(PREDICTIVE_MLPA_POSITIVE).size.positive?
                  exon_variant = @report_string.match(PREDICTIVE_MLPA_POSITIVE)
                  positive_gene = [exon_variant[:brca]]
                  extract_exon_variant(positive_gene, exon_variant)
                elsif @report_string.scan(CDNA_VARIANT_CLASS_REGEX).size.positive?
                  cdna_variant = @report_string.match(CDNA_VARIANT_CLASS_REGEX)
                  positive_gene = [cdna_variant[:brca]]
                  extract_cdna_variant_information(positive_gene, cdna_variant)
                end
              end
            end

            # TODO: find more exceptions
            def process_variant_class_records
              tested_gene = @genotype_string.match(VARIANT_CLASS_REGEX)[:brca]
              positive_gene = [DEPRECATED_BRCA_NAMES_MAP[tested_gene]]
              if @report_string.scan(EXON_LOCATION).size.positive?
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                exon_variants = @report_string.match(EXON_LOCATION)
                extract_exon_variant(positive_gene, exon_variants)
              elsif @report_string.scan(PROMOTER_EXON_LOCATION).size.positive?
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                exon_variants = @report_string.match(PROMOTER_EXON_LOCATION)
                extract_exon_variant(positive_gene, exon_variants)
              elsif @report_string.scan(EXON_LOCATION_EXCEPTIONS).size.positive?
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                exon_variants = @report_string.match(EXON_LOCATION_EXCEPTIONS)
                extract_exon_variant(positive_gene, exon_variants)
              elsif @report_string.scan(CDNA_VARIANT_CLASS_REGEX).size.positive?
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                cdna_variant = @report_string.match(CDNA_VARIANT_CLASS_REGEX)
                extract_cdna_variant_information(positive_gene, cdna_variant)
              elsif @report_string.scan(CDNA_MUTATION_TYPES_REGEX).size.positive?
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                cdna_variant = @report_string.match(CDNA_MUTATION_TYPES_REGEX)
                extract_cdna_variant_information(positive_gene, cdna_variant)
              end
              @genotypes
            end

            def extract_double_cdna_variants(positive_gene)
              cdnas = @report_string.scan(CDNA_REGEX).flatten.compact.uniq
              if @report_string.scan(PROTEIN_REGEX).uniq.size == 2
                proteins = @report_string.scan(PROTEIN_REGEX).flatten.compact
                variants = cdnas.zip(proteins)
                variants.each do |cdna, protein|
                  mutant_genotype = @genotype.dup
                  mutant_genotype.add_gene(positive_gene.join)
                  mutant_genotype.add_gene_location(cdna)
                  mutant_genotype.add_protein_impact(protein)
                  mutant_genotype.add_status(2)
                  @genotypes.append(mutant_genotype)
                end
              else
                cdnas.each do |cdna|
                  mutant_genotype = @genotype.dup
                  mutant_genotype.add_gene(positive_gene.join)
                  mutant_genotype.add_gene_location(cdna)
                  mutant_genotype.add_status(2)
                  @genotypes.append(mutant_genotype)
                end
              end
              @genotypes
            end

            def extract_multiplecdnas_samegene(positive_gene)
              if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                process_negative_genes(positive_gene)
              end
              if @report_string.scan(CDNA_REGEX).uniq.size == 2
                extract_double_cdna_variants(positive_gene)
              else
                cdnas = @report_string.scan(CDNA_REGEX).flatten.compact.uniq
                cdnas.each do |cdna|
                  mutant_genotype = @genotype.dup
                  mutant_genotype.add_gene(positive_gene.join)
                  mutant_genotype.add_gene_location(cdna)
                  mutant_genotype.add_status(2)
                  @genotypes.append(mutant_genotype)
                end
                @genotypes
              end
            end

            def extract_multiplecdnas_multiplegene
              genes = @report_string.scan(BRCA_REGEX).uniq.flatten.compact
              cdnas = @report_string.scan(CDNA_REGEX).uniq.flatten.compact
              variants = genes.zip(cdnas)
              variants.each do |gene, cdna|
                mutant_genotype = @genotype.dup
                mutant_genotype.add_gene(gene)
                mutant_genotype.add_gene_location(cdna)
                mutant_genotype.add_status(2)
                @genotypes.append(mutant_genotype)
              end
            end

            def process_variantseq_tests
              positive_gene = [@report_string.match(BRCA_REGEX)[:brca]]
              if @report_string.scan(CDNA_REGEX).uniq.size > 1
                case @report_string.scan(BRCA_REGEX).uniq.size
                when 1
                  extract_multiplecdnas_samegene(positive_gene)
                when 2
                  extract_multiplecdnas_multiplegene
                end
              else
                if @genotype.attribute_map['genetictestscope'] == 'Full screen BRCA1 and BRCA2'
                  process_negative_genes(positive_gene)
                end
                cdna_variant = @report_string.match(GENE_LOCATION)
                extract_cdna_variant_information(positive_gene, cdna_variant)
              end
            end

            def process_negative_genes(positive_gene)
              negative_genes = %w[BRCA1 BRCA2] - positive_gene
              negative_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(1)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_negative_genes_w_palb2(positive_gene)
              negative_genes = %w[BRCA1 BRCA2 PALB2] - positive_gene
              negative_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(1)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def process_predictive_tests
              if @report_string.scan(PREDICTIVE_REPORT_REGEX_POSITIVE).size.positive?
                process_positive_predictive
              elsif @report_string.scan(PREDICTIVE_REPORT_REGEX_NEGATIVE).size.positive?
                process_negative_predictive
              elsif @report_string.scan(PREDICTIVE_REPORT_NEGATIVE_INHERITED_REGEX).size.positive?
                process_negative_inherited_predictive
              elsif @report_string.scan(PREDICTIVE_POSITIVE_EXON).size.positive?
                process_positive_predictive_exonvariant
              elsif @report_string.scan(PREDICTIVE_MLPA_NEGATIVE).size.positive?
                process_negative_mlpa_predictive
              elsif @report_string.scan(PREDICTIVE_MLPA_POSITIVE).size.positive?
                process_positive_mlpa_predictive
              end
            end

            def process_positive_predictive
              cdna_variant = @report_string.gsub('\n', '').match(PREDICTIVE_REPORT_REGEX_POSITIVE)
              positive_gene = [cdna_variant[:brca]]
              extract_cdna_variant_information(positive_gene, cdna_variant)
              @logger.debug 'Sucessfully parsed positive pred record'
            end

            def process_negative_predictive
              Maybe(@report_string.match(PREDICTIVE_REPORT_REGEX_NEGATIVE)[:brca]).map do |x|
                @genotype.add_gene(x)
              end
              @genotype.add_status(1)
              @genotypes.append(@genotype)
              @logger.debug 'Sucessfully parsed negative pred record'
            end

            def process_negative_inherited_predictive
              Maybe(@report_string.match(PREDICTIVE_REPORT_NEGATIVE_INHERITED_REGEX)[:brca]).map do |x|
                @genotype.add_gene(x)
              end
              @genotype.add_status(1)
              @genotypes.append(@genotype)
              @logger.debug 'Sucessfully parsed negative INHERITED pred record'
            end

            def process_positive_predictive_exonvariant
              exon_variant = @report_string.gsub('\n', '').match(PREDICTIVE_POSITIVE_EXON)
              positive_gene = [exon_variant[:brca]]
              extract_exon_variant(positive_gene, exon_variant)
            end

            def process_negative_mlpa_predictive
              Maybe(@report_string.match(PREDICTIVE_MLPA_NEGATIVE)[:brca]).map do |x|
                @genotype.add_gene(x)
              end
              @genotype.add_status(1)
              @genotypes.append(@genotype)
              @logger.debug 'Sucessfully parsed NEGATIVE MLPA pred record'
            end

            def process_positive_mlpa_predictive
              exon_variant = @report_string.gsub('\n', '').match(PREDICTIVE_MLPA_POSITIVE)
              positive_gene = [exon_variant[:brca]]
              extract_exon_variant(positive_gene, exon_variant)
            end

            def extract_cdna_variant_information(positive_gene, cdna_variant)
              @genotype.add_gene(positive_gene.join)
              Maybe(cdna_variant[:location]).map { |x| @genotype.add_gene_location(x) } if
              cdna_variant.names.include? 'location'
              Maybe(cdna_variant[:impact]).map { |x| @genotype.add_protein_impact(x) } if
              cdna_variant.names.include? 'impact'
              Maybe(cdna_variant[:zygosity]).map { |x| @genotype.add_zygosity(x) } if
              cdna_variant.names.include? 'zigosity'
              Maybe(cdna_variant[:variantclass]).map { |x| @genotype.add_variant_class(x) } if
              cdna_variant.names.include? 'variantclass'
              Maybe(cdna_variant[:type]).map { |x| @genotype.add_variant_impact(x) } if
              cdna_variant.names.include? 'type'
              @genotype.add_status(2)
              @genotypes.append(@genotype)
            end

            def brca_double_negative
              reported_genes = %w[BRCA1 BRCA2]
              reported_genes.each do |negative_gene|
                genotype2 = @genotype.dup
                genotype2.add_gene(negative_gene)
                genotype2.add_status(1)
                @genotypes.append(genotype2)
              end
              @genotypes
            end

            def extract_exon_variant(positive_gene, exon_variant)
              @genotype.add_gene(positive_gene.join)
              Maybe(exon_variant[:zygosity]).map { |x| @genotype.add_zygosity(x)} if
              exon_variant.names.include? 'zygosity'
              Maybe(exon_variant[:variantclass]).map { |x| @genotype.add_variant_class(x) } if
              exon_variant.names.include? 'variantclass'
              Maybe(exon_variant[:mutationtype]).map { |x| @genotype.add_variant_type(x) } if
              exon_variant.names.include? 'mutationtype'
              Maybe(exon_variant[:exons]).map { |x| @genotype.add_exon_location(x) } if
              exon_variant.names.include? 'exons'
              @genotype.add_status(2)
              @genotypes.append(@genotype)
            end
          end
        end
      end
    end
  end
end