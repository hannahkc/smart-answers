require_relative "../../test_helper"

module SmartAnswer::Calculators
  class SelfAssessmentPenaltiesTest < ActiveSupport::TestCase
    def setup
      test_calculator_dates = {
        online_filing_deadline: {
          "2012-13": Date.new(2014, 1, 31),
          "2013-14": Date.new(2015, 1, 31),
          "2014-15": Date.new(2015, 1, 31),
          "2015-16": Date.new(2017, 1, 31)
        },
        offline_filing_deadline: {
          "2012-13": Date.new(2013, 10, 31),
          "2013-14": Date.new(2014, 10, 31),
          "2015-16": Date.new(2016, 10, 31)
        },
        payment_deadline: {
          "2012-13": Date.new(2014, 1, 31),
          "2013-14": Date.new(2015, 1, 31),
          "2015-16": Date.new(2017, 1, 31)
        },
      }

      @calculator = SelfAssessmentPenalties.new(
        submission_method: "online", filing_date: Date.parse("2014-01-10"),
        payment_date: Date.parse("2014-03-10"), estimated_bill: SmartAnswer::Money.new(5000),
        dates: test_calculator_dates,
        tax_year: "2012-13"
      )
    end

    context '#start_of_next_year' do
      should 'return 2013-04-06 if tax-year is 2012-13' do
        @calculator.tax_year = '2012-13'

        assert_equal Date.new(2013, 4, 6), @calculator.start_of_next_tax_year
      end
      should 'return 2014-04-06 if tax-year is 2013-14' do
        @calculator.tax_year = '2013-14'

        assert_equal Date.new(2014, 4, 6), @calculator.start_of_next_tax_year
      end
      should 'return 2015-04-06 if tax-year is 2014-15' do
        @calculator.tax_year = '2014-15'

        assert_equal Date.new(2015, 4, 6), @calculator.start_of_next_tax_year
      end
      should 'return 2016-04-06 if tax-year is 2016-15' do
        @calculator.tax_year = '2015-16'

        assert_equal Date.new(2016, 4, 6), @calculator.start_of_next_tax_year
      end
    end

    context 'one_year_after_start_date_for_penalties' do
      should 'return 2015-02-01 if tax-year is 2012-13' do
        @calculator.tax_year = '2012-13'

        assert_equal Date.new(2015, 2, 1), @calculator.one_year_after_start_date_for_penalties
      end
      should 'return 2016-02-01 if tax-year is 2013-14' do
        @calculator.tax_year = '2013-14'

        assert_equal Date.new(2016, 2, 1), @calculator.one_year_after_start_date_for_penalties
      end
      should 'return 2017-02-01 if tax-year is 2014-15' do
        @calculator.tax_year = '2014-15'

        assert_equal Date.new(2017, 2, 1), @calculator.one_year_after_start_date_for_penalties
      end
      should 'return 2018-02-01 if tax-year is 2015-16' do
        @calculator.tax_year = '2015-16'

        assert_equal Date.new(2018, 2, 1), @calculator.one_year_after_start_date_for_penalties
      end
    end

    context "valid_filing_date?" do
      should "be valid if filing date is on or after start of next tax year" do
        @calculator.filing_date = @calculator.start_of_next_tax_year
        assert @calculator.valid_filing_date?
      end

      should "be invalid if filing date is before start of next tax year" do
        @calculator.filing_date = @calculator.start_of_next_tax_year - 1
        refute @calculator.valid_filing_date?
      end
    end

    context "valid_payment_date?" do
      should "be valid if payment date is on or after filing date" do
        @calculator.payment_date = @calculator.filing_date
        assert @calculator.valid_payment_date?
      end

      should "be invalid if filing date is before filing date" do
        @calculator.payment_date = @calculator.filing_date - 1
        refute @calculator.valid_payment_date?
      end
    end

    context "online submission" do
      context "filed and paid on time" do
        setup do
          @calculator.filing_date = Date.parse("2014-01-10")
          @calculator.payment_date = Date.parse("2014-01-10")
        end

        should "confirm payment was made on time" do
          assert @calculator.paid_on_time?
        end
      end # on time

      context "filed or paid late" do
        should "confirm payment was made late" do
          refute @calculator.paid_on_time?
        end
        should "calculate late filing penalty" do
          # band one
          @calculator.filing_date = Date.parse("2014-02-02")
          assert_equal 100, @calculator.late_filing_penalty
          # band two
          @calculator.filing_date = Date.parse("2014-05-01")
          assert_equal 110, @calculator.late_filing_penalty
          # band three
          @calculator.filing_date = Date.parse("2014-05-02")
          assert_equal 120, @calculator.late_filing_penalty
          @calculator.filing_date = Date.parse("2014-06-06")
          assert_equal 470, @calculator.late_filing_penalty
          @calculator.filing_date = Date.parse("2014-07-29")
          assert_equal 1000, @calculator.late_filing_penalty
          # band four
          @calculator.filing_date = Date.parse("2014-09-06")
          assert_equal 1300, @calculator.late_filing_penalty
          # band four (1000 + 5% of estimated bill larger than £300)
          @calculator.estimated_bill = SmartAnswer::Money.new(11000)
          assert_equal 1550, @calculator.late_filing_penalty
          # band five
          @calculator.estimated_bill = SmartAnswer::Money.new(0)
          @calculator.filing_date = Date.parse("2015-02-02")
          assert_equal 1600, @calculator.late_filing_penalty
          # band five (1000 + 5% estimated bill larger than £600)
          @calculator.estimated_bill = SmartAnswer::Money.new(10000)
          assert_equal 2000, @calculator.late_filing_penalty
          # from 6 to 12 months, tax <=6002
          @calculator.filing_date = Date.parse("2014-10-31")
          @calculator.estimated_bill = SmartAnswer::Money.new(10000)
          assert_equal 1500, @calculator.late_filing_penalty
          # from 6 to 12 months, tax >6002
          @calculator.filing_date = Date.parse("2014-10-31")
          @calculator.estimated_bill = SmartAnswer::Money.new(10000)
          assert_equal 1500, @calculator.late_filing_penalty
        end

        should "calculate interest and late payment penalty" do
          @calculator.estimated_bill = SmartAnswer::Money.new(10000)
          @calculator.payment_date = Date.parse("2014-01-01")
          assert_equal 0, @calculator.interest
          # 1 day after the deadline
          @calculator.payment_date = Date.parse("2014-02-01")
          assert_equal 0, @calculator.interest
          # 31 days after the deadline
          @calculator.payment_date = Date.parse("2014-03-03")
          assert_equal 24.66, @calculator.interest
          assert_equal 500, @calculator.late_payment_penalty
          # should calculate PenaltyInterest1
          @calculator.payment_date = Date.parse("2014-04-02")
          assert_equal 49.32, @calculator.interest #50.14 + 0.04 penalty interest
          # one day before late payment penalty 2
          @calculator.payment_date = Date.parse("2014-08-01")
          assert_equal 1000, @calculator.late_payment_penalty
          assert_equal 148.77, @calculator.interest
          # should calculate PenaltyInterest2
          @calculator.payment_date = Date.parse("2014-09-02")
          assert_equal 1000, @calculator.late_payment_penalty
          assert_equal 175.07, @calculator.interest
          # one day before late payment penalty 3
          @calculator.payment_date = Date.parse("2015-02-01")
          assert_equal 1500, @calculator.late_payment_penalty
          assert_equal 300, @calculator.interest
          # should apply late payment penalty 3
          @calculator.payment_date = Date.parse("2015-02-02")
          assert_equal 1500, @calculator.late_payment_penalty
          assert_equal 300.82, @calculator.interest
          # should calculate PenaltyInterest3
          @calculator.payment_date = Date.parse("2015-03-05")
          assert_equal 1500, @calculator.late_payment_penalty
          assert_equal 326.3, @calculator.interest
        end

        should "calculate total owed (excludes filing penalty)" do
          @calculator.payment_date = Date.parse("2014-02-02")
          assert_equal 5000, @calculator.total_owed
          @calculator.payment_date = Date.parse("2014-02-04")
          assert_equal 5001, @calculator.total_owed
          @calculator.payment_date = Date.parse("2014-08-01")
          assert_equal 5574, @calculator.total_owed
          @calculator.payment_date = Date.parse("2015-02-02")
          assert_equal 750, @calculator.late_payment_penalty
          assert_equal 5900, @calculator.total_owed
        end
      end # filed or paid late
    end # online submission

    context "offline submission" do
      setup do
        @calculator.submission_method = "paper"
      end
      context "filed and paid on time" do
        setup do
          @calculator.filing_date = Date.parse("2012-10-30")
          @calculator.payment_date = Date.parse("2013-01-30")
        end

        should "confirm payment was made on time" do
          assert @calculator.paid_on_time?
        end
      end

      context "filed or paid late" do
        setup do
          @calculator.filing_date = Date.parse("2013-01-10")
          @calculator.payment_date = Date.parse("2014-02-01")
        end
        should "confirm payment was made late" do
          refute @calculator.paid_on_time?
        end
      end

      context "interest calculated at different rates" do
        context "rate drops from 3% to 2.75% on 23 August 2016" do
          setup do
            @calculator.estimated_bill = SmartAnswer::Money.new(10000)
          end

          should "be more before 22 Aug 2016" do
            @calculator.tax_year = "2014-15"
            @calculator.payment_date = Date.parse("2016-08-22")
            old_rate_interest = @calculator.interest.value.floor

            @calculator.tax_year = "2015-16"
            @calculator.payment_date = Date.parse("2017-08-22")
            new_rate_interest = @calculator.interest.value.floor
            assert old_rate_interest > new_rate_interest
          end
        end
      end
    end
  end
end
