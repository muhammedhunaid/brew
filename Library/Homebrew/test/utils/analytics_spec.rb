# typed: false
# frozen_string_literal: true

require "utils/analytics"
require "formula_installer"

describe Utils::Analytics do
  describe "::os_arch_prefix_ci" do
    context "when os_arch_prefix_ci is not set" do
      before do
        described_class.clear_os_arch_prefix_ci
      end

      let(:ci) { ", CI" if ENV["CI"] }

      it "returns OS_VERSION and prefix when HOMEBREW_PREFIX is a custom prefix on intel" do
        allow(Hardware::CPU).to receive(:type).and_return(:intel)
        allow(Hardware::CPU).to receive(:in_rosetta2?).and_return(false)
        allow(Homebrew).to receive(:default_prefix?).and_return(false)
        expected = "#{OS_VERSION}, #{described_class.custom_prefix_label}#{ci}"
        expect(described_class.os_arch_prefix_ci).to eq expected
      end

      it "returns OS_VERSION, ARM and prefix when HOMEBREW_PREFIX is a custom prefix on arm" do
        allow(Hardware::CPU).to receive(:type).and_return(:arm)
        allow(Hardware::CPU).to receive(:in_rosetta2?).and_return(false)
        allow(Homebrew).to receive(:default_prefix?).and_return(false)
        expected = "#{OS_VERSION}, ARM, #{described_class.custom_prefix_label}#{ci}"
        expect(described_class.os_arch_prefix_ci).to eq expected
      end

      it "returns OS_VERSION, Rosetta and prefix when HOMEBREW_PREFIX is a custom prefix on Rosetta", :needs_macos do
        allow(Hardware::CPU).to receive(:type).and_return(:intel)
        allow(Hardware::CPU).to receive(:in_rosetta2?).and_return(true)
        allow(Homebrew).to receive(:default_prefix?).and_return(false)
        expected = "#{OS_VERSION}, Rosetta, #{described_class.custom_prefix_label}#{ci}"
        expect(described_class.os_arch_prefix_ci).to eq expected
      end

      it "does not include prefix when HOMEBREW_PREFIX is the default prefix" do
        allow(Homebrew).to receive(:default_prefix?).and_return(true)
        expect(described_class.os_arch_prefix_ci).not_to include(described_class.custom_prefix_label)
      end

      it "includes CI when ENV['CI'] is set" do
        ENV["CI"] = "true"
        expect(described_class.os_arch_prefix_ci).to include("CI")
      end
    end
  end

  describe "::report_event" do
    let(:f) { formula { url "foo-1.0" } }
    let(:options) { FormulaInstaller.new(f).display_options(f) }
    let(:action)  { "#{f.full_name} #{options}".strip }

    context "when ENV vars is set" do
      it "returns nil when HOMEBREW_NO_ANALYTICS is true" do
        ENV["HOMEBREW_NO_ANALYTICS"] = "true"
        expect(described_class.report_event("install", action)).to be_nil
      end

      it "returns nil when HOMEBREW_NO_ANALYTICS_THIS_RUN is true" do
        ENV["HOMEBREW_NO_ANALYTICS_THIS_RUN"] = "true"
        expect(described_class.report_event("install", action)).to be_nil
      end

      it "returns nil when HOMEBREW_ANALYTICS_DEBUG is true" do
        ENV.delete("HOMEBREW_NO_ANALYTICS_THIS_RUN")
        ENV.delete("HOMEBREW_NO_ANALYTICS")
        ENV["HOMEBREW_ANALYTICS_DEBUG"] = "true"
        expect(described_class.report_event("install", action)).to be_nil
      end
    end
  end

  describe "::report_build_error" do
    context "when tap is installed" do
      let(:err) { BuildError.new(f, "badprg", %w[arg1 arg2], {}) }
      let(:f) { formula { url "foo-1.0" } }

      it "reports event if BuildError raised for a formula with a public remote repository" do
        allow_any_instance_of(Tap).to receive(:custom_remote?).and_return(false)
        expect(described_class).to respond_to(:report_event)
        described_class.report_build_error(err)
      end

      it "does not report event if BuildError raised for a formula with a private remote repository" do
        expect(described_class.report_build_error(err)).to be_nil
      end
    end

    context "when formula does not have a tap" do
      let(:err) { BuildError.new(f, "badprg", %w[arg1 arg2], {}) }
      let(:f) { double(Formula, name: "foo", path: "blah", tap: nil) }

      it "does not report event if BuildError is raised" do
        expect(described_class.report_build_error(err)).to be_nil
      end
    end

    context "when tap for a formula is not installed" do
      let(:err) { BuildError.new(f, "badprg", %w[arg1 arg2], {}) }
      let(:f) { double(Formula, name: "foo", path: "blah", tap: CoreTap.instance) }

      it "does not report event if BuildError is raised" do
        allow_any_instance_of(Pathname).to receive(:directory?).and_return(false)
        expect(described_class.report_build_error(err)).to be_nil
      end
    end
  end

  specify "::table_output" do
    results = { ack: 10, wget: 100 }
    expect { described_class.table_output("install", "30", results) }
      .to output(/110 |  100.00%/).to_stdout
      .and not_to_output.to_stderr
  end
end
