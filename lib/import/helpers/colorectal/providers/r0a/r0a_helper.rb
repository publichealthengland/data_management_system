module Import
  module Helpers
    module Colorectal
      module Providers
        module R0a
          # Processing methods used by ManchesterHandlerColorectal
          module R0aHelper
            include Import::Helpers::Colorectal::Providers::R0a::R0aConstants

            def assign_and_populate_results_for(record)
              genocolorectal = Import::Colorectal::Core::Genocolorectal.new(record)
              genocolorectal.add_passthrough_fields(record.mapped_fields,
                                                    record.raw_fields,
                                                    PASS_THROUGH_FIELDS_COLO)
              add_servicereportidentifier(genocolorectal, record)
              testscope_from_rawfields(genocolorectal, record)
              results = assign_gene_mutation(genocolorectal, record)
              results.each { |genotype| @persister.integrate_and_store(genotype) }
            end

            def assign_gene_mutation(genocolorectal, _record)
              genotypes = []
              genes     = []
              if non_dosage_test?
                process_non_dosage_test_exons(genes)
                tests = tests_from_non_dosage_record(genes)
                grouped_tests = grouped_tests_from(tests)
                process_grouped_non_dosage_tests(grouped_tests, genocolorectal, genotypes)
              elsif dosage_test?
                process_dosage_test_exons(genes)
                tests = tests_from_dosage_record(genes)
                grouped_tests = grouped_tests_from(tests)
                process_grouped_dosage_tests(grouped_tests, genocolorectal, genotypes)
              end
              genotypes
            end

            def testscope_from_rawfields(genocolorectal, record)
              moltesttypes = []
              genera       = []
              exons        = []
              record.raw_fields.map do |raw_record|
                moltesttypes.append(raw_record['moleculartestingtype'])
                genera.append(raw_record['genus'])
                exons.append(raw_record['exon'])
              end

              add_test_scope_to(genocolorectal, moltesttypes, genera, exons)
            end

            # TODO: Boyscout
            def add_test_scope_to(genocolorectal, moltesttypes, genera, exons)
              stringed_moltesttypes = moltesttypes.flatten.join(',')
              stringed_exons = exons.flatten.join(',')

              if stringed_moltesttypes =~ /predictive|confirm/i
                genocolorectal.add_test_scope(:targeted_mutation)
              elsif genera.include?('G') || genera.include?('F')
                genocolorectal.add_test_scope(:full_screen)
              elsif (screen?(stringed_moltesttypes) || mlh1_msh2_6_test?(moltesttypes)) &&
                    twelve_tests_or_more?(moltesttypes)
                genocolorectal.add_test_scope(:full_screen)
              elsif (screen?(stringed_moltesttypes) || mlh1_msh2_6_test?(moltesttypes)) &&
                    !twelve_tests_or_more?(moltesttypes) && ngs?(stringed_exons)
                genocolorectal.add_test_scope(:full_screen)
              elsif (screen?(stringed_moltesttypes) || mlh1_msh2_6_test?(moltesttypes)) &&
                    !twelve_tests_or_more?(moltesttypes) && !ngs?(stringed_exons)
                genocolorectal.add_test_scope(:targeted_mutation)
              elsif moltesttypes.include?('VARIANT TESTING REPORT')
                genocolorectal.add_test_scope(:targeted_mutation)
              elsif stringed_moltesttypes =~ /dosage/i
                genocolorectal.add_test_scope(:full_screen)
              elsif moltesttypes.include?('HNPCC MSH2 c.942+3A>T MUTATION TESTING REPORT')
                genocolorectal.add_test_scope(:full_screen)
              end
            end

            def process_grouped_non_dosage_tests(grouped_tests, genocolorectal, genotypes)
              selected_genes = (@non_dosage_record_map[:moleculartestingtype].uniq &
                                MOLTEST_MAP.keys).join
              return @logger.debug('Nothing to do') if selected_genes.to_s.blank?

              grouped_tests.each do |gene, genetic_info|
                next unless MOLTEST_MAP[selected_genes].include? gene

                if cdna_match?(genetic_info)
                  process_non_dosage_cdna(gene, genetic_info, genocolorectal, genotypes)
                elsif !cdna_match?(genetic_info) && normal?(genetic_info)
                  process_non_cdna_normal(gene, genetic_info, genocolorectal, genotypes)
                elsif !cdna_match?(genetic_info) && !normal?(genetic_info) && fail?(genetic_info)
                  process_non_cdna_fail(gene, genetic_info, genocolorectal, genotypes)
                end
              end
            end

            def process_non_dosage_cdna(gene, genetic_info, genocolorectal, genotypes)
              genocolorectal_dup = genocolorectal.dup_colo
              colorectal_genes   = colorectal_genes_from(genetic_info)
              if colorectal_genes
                process_colorectal_genes(colorectal_genes, genocolorectal_dup, gene, genetic_info,
                                         genotypes)
              else
                process_non_colorectal_genes(genocolorectal_dup, gene, genetic_info, genotypes)
              end
            end

            def process_non_cdna_normal(gene, genetic_info, genocolorectal, genotypes)
              genocolorectal_dup = genocolorectal.dup_colo
              @logger.debug("IDENTIFIED #{gene}, NORMAL TEST from #{genetic_info}")
              add_gene_and_status_to(genocolorectal_dup, gene, 1, genotypes)
            end

            def process_non_cdna_fail(gene, genetic_info, genocolorectal, genotypes)
              genocolorectal_dup = genocolorectal.dup_colo
              add_gene_and_status_to(genocolorectal_dup, gene, 9, genotypes)
              @logger.debug("Adding #{gene} to FAIL STATUS for #{genetic_info}")
            end

            def process_false_positive(colorectal_genes, gene, genetic_info)
              @logger.debug("IDENTIFIED FALSE POSITIVE FOR #{gene}, " \
                            "#{colorectal_genes[:colorectal]}, #{cdna_from(genetic_info)} " \
                            "from #{genetic_info}")
            end

            def process_colorectal_genes(colorectal_genes, genocolorectal_dup, gene, genetic_info,
                                         genotypes)
              if colorectal_genes[:colorectal] != gene
                process_false_positive(colorectal_genes, gene, genetic_info)
              elsif colorectal_genes[:colorectal] == gene
                @logger.debug("IDENTIFIED TRUE POSITIVE FOR #{gene}, " \
                              "#{cdna_from(genetic_info)} from #{genetic_info}")
                genocolorectal_dup.add_gene_location(cdna_from(genetic_info))
                if PROT_REGEX.match(genetic_info.join(','))
                  @logger.debug("IDENTIFIED #{protien_from(genetic_info)} from #{genetic_info}")
                  genocolorectal_dup.add_protein_impact(protien_from(genetic_info))
                end
                add_gene_and_status_to(genocolorectal_dup, gene, 2, genotypes)
                @logger.debug("IDENTIFIED #{gene}, POSITIVE TEST from #{genetic_info}")
              end
            end

            def process_non_colorectal_genes(genocolorectal_dup, gene, genetic_info, genotypes)
              @logger.debug("IDENTIFIED #{gene}, #{cdna_from(genetic_info)} from #{genetic_info}")
              genocolorectal_dup.add_gene_location(cdna_from(genetic_info))
              if PROT_REGEX.match(genetic_info.join(','))
                @logger.debug("IDENTIFIED #{protien_from(genetic_info)} from #{genetic_info}")
                genocolorectal_dup.add_protein_impact(protien_from(genetic_info))
              end
              add_gene_and_status_to(genocolorectal_dup, gene, 2, genotypes)
              @logger.debug("IDENTIFIED #{gene}, POSITIVE TEST from #{genetic_info}")
            end

            # TODO: Boyscout
            def process_grouped_dosage_tests(grouped_tests, genocolorectal, genotypes)
              selected_genes = (@dosage_record_map[:moleculartestingtype].uniq &
                                MOLTEST_MAP_DOSAGE.keys).join
              return @logger.debug('Nothing to do') if selected_genes.to_s.blank?

              grouped_tests.compact.select do |gene, genetic_info|
                dosage_genes = MOLTEST_MAP_DOSAGE[selected_genes]
                if dosage_genes.include? gene
                  process_dosage_gene(gene, genetic_info, genocolorectal, genotypes, dosage_genes)
                else
                  @logger.debug("Nothing to be done for #{gene} as it is not in #{selected_genes}")
                end
              end
            end

            def process_dosage_gene(gene, genetic_info, genocolorectal, genotypes, dosage_genes)
              if !colorectal_gene_match?(genetic_info)
                genocolorectal_dup = genocolorectal.dup_colo
                add_gene_and_status_to(genocolorectal_dup, gene, 1, genotypes)
                @logger.debug("IDENTIFIED #{gene} from #{dosage_genes}, " \
                              "NORMAL TEST from #{genetic_info}")
              elsif colorectal_gene_match?(genetic_info) && !exon_match?(genetic_info)
                genocolorectal_dup = genocolorectal.dup_colo
                add_gene_and_status_to(genocolorectal_dup, gene, 1, genotypes)
                @logger.debug("IDENTIFIED #{gene} from #{dosage_genes}, " \
                              "NORMAL TEST from #{genetic_info}")
              elsif colorectal_gene_match?(genetic_info) && exon_match?(genetic_info)
                process_colorectal_gene_and_exon_match(genocolorectal, genetic_info, genotypes)
              end
            end

            def process_colorectal_gene_and_exon_match(genocolorectal, genetic_info, genotypes)
              genocolorectal_dup = genocolorectal.dup_colo
              colorectal_gene    = colorectal_genes_from(genetic_info)[:colorectal]
              genocolorectal_dup.add_gene_colorectal(colorectal_gene)
              genocolorectal_dup.add_variant_type(exon_from(genetic_info))
              if EXON_LOCATION_REGEX.match(genetic_info.join(','))
                exon_locations = exon_locations_from(genetic_info)
                if exon_locations.one?
                  genocolorectal_dup.add_exon_location(exon_locations.flatten.first)
                elsif exon_locations.size == 2
                  genocolorectal_dup.add_exon_location(exon_locations.flatten.compact.join('-'))
                end
              end
              genocolorectal_dup.add_status(2)
              genotypes.append(genocolorectal_dup)
            end

            def add_servicereportidentifier(genocolorectal, record)
              servicereportidentifiers = []
              record.raw_fields.each do |records|
                servicereportidentifiers << records['servicereportidentifier']
              end
              servicereportidentifier = servicereportidentifiers.flatten.uniq.join
              genocolorectal.attribute_map['servicereportidentifier'] = servicereportidentifier
            end

            def add_gene_and_status_to(genocolorectal_dup, gene, status, genotypes)
              genocolorectal_dup.add_gene_colorectal(gene)
              genocolorectal_dup.add_status(status)
              genotypes.append(genocolorectal_dup)
            end

            def grouped_tests_from(tests)
              grouped_tests = Hash.new { |h, k| h[k] = [] }
              tests.each do |test_array|
                gene = test_array.first
                test_array[1..-1].each { |test_value| grouped_tests[gene] << test_value }
              end

              grouped_tests.transform_values!(&:uniq)
            end

            def tests_from_non_dosage_record(genes)
              return if genes.nil?

              genes.zip(@non_dosage_record_map[:genotype],
                        @non_dosage_record_map[:genotype2]).uniq
            end

            def tests_from_dosage_record(genes)
              return if genes.nil?

              genes.zip(@dosage_record_map[:genotype],
                        @dosage_record_map[:genotype2],
                        @dosage_record_map[:moleculartestingtype]).uniq
            end

            def process_non_dosage_test_exons(genes)
              @non_dosage_record_map[:exon].each do |exons|
                if exons =~ COLORECTAL_GENES_REGEX
                  genes.append(COLORECTAL_GENES_REGEX.match(exons)[:colorectal])
                else
                  genes.append('No Gene')
                end
              end
            end

            def process_dosage_test_exons(genes)
              @dosage_record_map[:exon].map do |exons|
                if exons.scan(COLORECTAL_GENES_REGEX).count.positive? && mlpa?(exons)
                  exons.scan(COLORECTAL_GENES_REGEX).flatten.each { |gene| genes.append(gene) }
                else
                  genes.append('No Gene')
                end
              end
            end

            def relevant_consultant?(raw_record)
              raw_record['consultantname'].to_s.upcase != 'DR SANDI DEANS'
            end

            def mlh1_msh2_6_test?(moltesttypes)
              moltesttypes.include?('MLH1/MSH2/MSH6 GENETIC TESTING REPORT')
            end

            def ngs?(exons)
              exons =~ /ngs/i.freeze
            end

            def screen?(moltesttypes)
              moltesttypes =~ /screen/i.freeze
            end

            def control_sample?(raw_record)
              raw_record['genocomm'] =~ /control|ctrl/i
            end

            def twelve_tests_or_more?(moltesttypes)
              moltesttypes.size >= 12
            end

            def non_dosage_test?
              (MOLTEST_MAP.keys & @non_dosage_record_map[:moleculartestingtype].uniq).size == 1
            end

            def dosage_test?
              (MOLTEST_MAP_DOSAGE.keys & @dosage_record_map[:moleculartestingtype].uniq).size == 1
            end

            def colorectal_gene_match?(genetic_info)
              genetic_info.join(',') =~ COLORECTAL_GENES_REGEX
            end

            def cdna_match?(genetic_info)
              genetic_info.join(',') =~ CDNA_REGEX
            end

            def exon_match?(genetic_info)
              genetic_info.join(',') =~ EXON_REGEX
            end

            def normal?(genetic_info)
              genetic_info.join(',') =~ /normal/i
            end

            def fail?(genetic_info)
              genetic_info.join(',') =~ /fail/i
            end

            def mlpa?(exon)
              exon =~ /mlpa/i
            end

            def cdna_from(genetic_info)
              CDNA_REGEX.match(genetic_info.join(','))[:cdna]
            end

            def exon_from(genetic_info)
              EXON_REGEX.match(genetic_info.join(','))[:insdeldup]
            end

            def exon_locations_from(genetic_info)
              genetic_info.join(',').scan(EXON_LOCATION_REGEX)
            end

            def protien_from(genetic_info)
              PROT_REGEX.match(genetic_info.join(','))[:impact]
            end

            def colorectal_genes_from(genetic_info)
              COLORECTAL_GENES_REGEX.match(genetic_info.join(','))
            end

            def process_genocolorectal(genocolorectal_dup, gene, status, logging, genotypes)
              @logger.debug(logging)
              genocolorectal_dup.add_gene_colorectal(gene)
              genocolorectal_dup.add_status(status)
              genotypes.append(genocolorectal_dup)
            end

            def normal_test_logging_for(selected_genes, gene, genetic_info)
              "IDENTIFIED #{gene} from #{MOLTEST_MAP_DOSAGE[selected_genes]}, " \
                "NORMAL TEST from #{genetic_info}"
            end
          end
        end
      end
    end
  end
end