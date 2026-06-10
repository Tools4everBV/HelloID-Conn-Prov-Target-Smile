# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [2.0.0] - 2026-06-10

### Added

- Added resource creation functionality for departments (resources/departments/resources.ps1)
- Added resource creation functionality for titles (resources/titles/resources.ps1)
- Added JSON body examples for account, department, and title resources (assets/)
- Added GitHub workflow for automated release creation (.github/workflows/createRelease.yaml)
- Added GitHub workflow for changelog verification (.github/workflows/verifyChangelog.yaml)
- Added standard field mapping file (fieldMapping_standard.json) with commonly used fields
- Added comprehensive setup documentation in README including Smile configuration steps
- Added development resources section with webhook endpoint documentation
- Added detailed remarks about EmployeeNumber handling, delete action behavior, and testing procedures

### Changed

- Refactored all lifecycle scripts (create.ps1, update.ps1, enable.ps1, disable.ps1, delete.ps1) with improved error handling and logging
- Enhanced update.ps1 to automatically add EmployeeNumber from AccountReference to prevent duplicates when source EmployeeNumber changes
- Updated fieldMapping.json to include new fields and ensure proper mapping for account attributes
- Completely rewrote README.md with extensive documentation including:
  - Supported features overview with detailed feature matrix
  - Step-by-step setup guide for Smile configuration
  - Expanded connection settings documentation
  - Detailed correlation configuration explanation
  - Field mapping guidance with fixed value field examples
  - Enhanced remarks section with comprehensive explanations
- Improved error handling across all scripts for better troubleshooting
- Updated logo reference to use GitHub raw URL

### Fixed

- Fixed EmployeeNumber handling in update script to prevent duplicate account creation when EmployeeNumber changes in source system
- Improved logging consistency across all lifecycle actions

## [1.0.0] - 2024-04-03

This is the first official release of _HelloID-Conn-Prov-Target-Smile_. This release is based on template version _1.0.1_.

### Added

- Initial release with basic lifecycle actions (create, update, enable, disable, delete)
- Basic field mapping configuration
- Connection settings for Smile webhook API
- Basic README documentation
