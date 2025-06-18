.PHONY: build-ios

build-ios:
	@echo "🧹 Cleaning Flutter build..."
	@flutter clean
	@echo "🗑️  Cleaning pub cache..."
	@flutter pub cache clean
	@echo "🏗️  Building IPA..."
	@flutter build ipa
	@echo "✅ Build process completed!"
