# frozen_string_literal: true

# Override Active Storage URLs to use custom CDN domain for cloudflare_public service
#
# Only the cloudflare_public service uses a public CDN domain.
# The regular cloudflare service uses Rails proxy URLs (private access).
#
# Setup:
# 1. In Cloudflare Dashboard: R2 → Bucket → Settings → Connect Domain
# 2. Add your custom domain (e.g., assets.gleania.com)
# 3. Set in credentials (rails credentials:edit):
#
#    cloudflare_public:
#      public_url: https://assets.gleania.com
#
#    Or environment variable:
#      CLOUDFLARE_ASSETS_URL=https://assets.gleania.com

Rails.application.config.after_initialize do
  cdn_host = ENV["CLOUDFLARE_ASSETS_URL"] || Rails.application.credentials.dig(:cloudflare_public, :public_url)

  if cdn_host.present?
    ActiveStorage::Blob.class_eval do
      # Returns the public URL using CDN domain for cloudflare_public service
      #
      # @return [String] The URL for the blob
      def url(*)
        # Only use CDN for cloudflare_public service
        if service_name.to_sym == :cloudflare_public
          cdn_host = ENV["CLOUDFLARE_ASSETS_URL"] || Rails.application.credentials.dig(:cloudflare_public, :public_url)
          "#{cdn_host}/#{key}"
        else
          # Fall back to default Active Storage URL generation for other services
          service.url(key, expires_in: ActiveStorage.service_urls_expire_in, filename: filename, disposition: "inline", content_type: content_type)
        end
      end
    end

    Rails.logger.info "[ActiveStorage] CDN host for cloudflare_public: #{cdn_host}"
  end
end
