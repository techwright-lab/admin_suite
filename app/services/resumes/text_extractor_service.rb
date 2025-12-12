# frozen_string_literal: true

module Resumes
  # Service for extracting text content from uploaded resume files
  #
  # Supports PDF, DOCX, DOC, and plain text files.
  #
  # @example
  #   service = Resumes::TextExtractorService.new(user_resume)
  #   result = service.extract
  #   if result[:success]
  #     puts result[:text]
  #   end
  #
  class TextExtractorService
    # Maximum text length to prevent memory issues
    MAX_TEXT_LENGTH = 500_000

    attr_reader :user_resume

    # Initialize the service
    #
    # @param user_resume [UserResume] The resume to extract text from
    def initialize(user_resume)
      @user_resume = user_resume
    end

    # Extracts text content from the resume file
    #
    # @return [Hash] Result with :success, :text, :error keys
    def extract
      return error_result("No file attached") unless user_resume.file.attached?

      text = case user_resume.file_extension
      when "pdf"
               extract_from_pdf
      when "docx"
               extract_from_docx
      when "doc"
               extract_from_doc
      when "txt"
               extract_from_text
      else
               return error_result("Unsupported file type: #{user_resume.file_extension}")
      end

      return error_result("No text content extracted") if text.blank?

      # Truncate if too long
      text = text.truncate(MAX_TEXT_LENGTH) if text.length > MAX_TEXT_LENGTH

      # Store the parsed text
      user_resume.update!(parsed_text: text)

      success_result(text)
    rescue PDF::Reader::MalformedPDFError => e
      error_result("Invalid or corrupted PDF file: #{e.message}")
    rescue Docx::Errors::DocxError => e
      error_result("Invalid or corrupted Word document: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Text extraction failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      error_result("Failed to extract text: #{e.message}")
    end

    private

    # Extracts text from PDF files
    #
    # @return [String] Extracted text
    def extract_from_pdf
      download_and_process do |tempfile|
        reader = PDF::Reader.new(tempfile.path)
        pages_text = reader.pages.map do |page|
          page.text
        rescue StandardError => e
          Rails.logger.warn("Failed to extract text from PDF page: #{e.message}")
          ""
        end
        pages_text.join("\n\n")
      end
    end

    # Extracts text from DOCX files
    #
    # @return [String] Extracted text
    def extract_from_docx
      download_and_process do |tempfile|
        doc = Docx::Document.open(tempfile.path)
        paragraphs = doc.paragraphs.map(&:text)
        paragraphs.join("\n\n")
      end
    end

    # Extracts text from DOC files (legacy Word format)
    # Falls back to antiword or catdoc if available, otherwise tries basic extraction
    #
    # @return [String] Extracted text
    def extract_from_doc
      download_and_process do |tempfile|
        # Try antiword first (common on Linux)
        if system("which antiword > /dev/null 2>&1")
          `antiword #{Shellwords.escape(tempfile.path)} 2>/dev/null`
        # Try catdoc as fallback
        elsif system("which catdoc > /dev/null 2>&1")
          `catdoc #{Shellwords.escape(tempfile.path)} 2>/dev/null`
        else
          # Basic fallback - try to read as text with encoding handling
          content = File.read(tempfile.path, encoding: "ISO-8859-1")
          # Extract readable text portions
          content.encode("UTF-8", invalid: :replace, undef: :replace)
                 .gsub(/[^\x20-\x7E\n\r\t]/, " ")
                 .gsub(/\s+/, " ")
                 .strip
        end
      end
    end

    # Extracts text from plain text files
    #
    # @return [String] Extracted text
    def extract_from_text
      download_and_process do |tempfile|
        File.read(tempfile.path, encoding: "UTF-8")
      rescue Encoding::InvalidByteSequenceError
        File.read(tempfile.path, encoding: "ISO-8859-1").encode("UTF-8")
      end
    end

    # Downloads the file to a tempfile and yields it for processing
    #
    # @yield [Tempfile] The downloaded file
    # @return [String] Result from the block
    def download_and_process
      extension = ".#{user_resume.file_extension}"
      tempfile = Tempfile.new([ "resume", extension ])
      tempfile.binmode

      begin
        user_resume.file.download { |chunk| tempfile.write(chunk) }
        tempfile.rewind
        yield tempfile
      ensure
        tempfile.close
        tempfile.unlink
      end
    end

    # Builds a success result hash
    #
    # @param text [String] Extracted text
    # @return [Hash]
    def success_result(text)
      {
        success: true,
        text: clean_text(text),
        char_count: text.length,
        word_count: text.split(/\s+/).count
      }
    end

    # Builds an error result hash
    #
    # @param message [String] Error message
    # @return [Hash]
    def error_result(message)
      {
        success: false,
        error: message
      }
    end

    # Cleans extracted text for better AI processing
    #
    # @param text [String] Raw text
    # @return [String] Cleaned text
    def clean_text(text)
      text
        .gsub(/\r\n/, "\n")           # Normalize line endings
        .gsub(/\r/, "\n")
        .gsub(/\n{3,}/, "\n\n")       # Collapse multiple newlines
        .gsub(/[ \t]+/, " ")          # Collapse multiple spaces
        .gsub(/^\s+$/, "")            # Remove whitespace-only lines
        .strip
    end
  end
end
