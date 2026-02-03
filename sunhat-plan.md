# Hatti App iOS 26 Upgrade Plan

## Overview
This plan outlines the comprehensive upgrade of the Hatti weather-based reminder app to iOS 26, including completing incomplete features and ensuring full compatibility with iOS 26 APIs and best practices.

## Current State
- **Swift Version:** 6.0 ✅
- **Current iOS Target:** 18.5 → 26.0
- **Architecture:** MVVM with SwiftData ✅
- **Key Features:** Weather reminders, location services, background updates

## Phase 1: Project Configuration Updates

### 1.1 Update iOS Deployment Target
- **File:** `hatti.xcodeproj/project.pbxproj`
- **Action:** Change `IPHONEOS_DEPLOYMENT_TARGET` from `18.5` to `26.0` in all build configurations
- **Impact:** Ensures app targets iOS 26 minimum

### 1.2 Update Info.plist for iOS 26
- **File:** `hatti/Info.plist`
- **Actions:**
  - Add iOS 26 specific privacy usage descriptions
  - Update background modes for iOS 26 compatibility
  - Add new iOS 26 entitlements

## Phase 2: Complete Incomplete Features

### 2.1 Location Integration
- **File:** `hatti/ViewModels/WeatherViewModel.swift`
- **Action:** Replace TODO with proper LocationPermissionManager integration
- **Implementation:**
  - Inject LocationPermissionManager instead of DefaultLocationManager
  - Handle location permission states properly
  - Integrate with existing location services

### 2.2 Background Weather Updates
- **File:** `hatti/Services/Weather/WeatherService.swift`
- **Action:** Update background refresh to use iOS 26 APIs
- **Implementation:**
  - Replace BGAppRefreshTaskRequest with iOS 26 background task APIs
  - Update background task scheduling logic
  - Ensure proper error handling for iOS 26

## Phase 3: iOS 26 API Updates

### 3.1 Location Services
- **File:** `hatti/Services/Location/LocationPermissionManager.swift`
- **Actions:**
  - Update to iOS 26 location privacy APIs
  - Add support for new location accuracy authorization
  - Implement iOS 26 location manager delegate methods
  - Add support for temporary location permission

### 3.2 WeatherKit Integration
- **File:** `hatti/Services/Weather/WeatherAPI.swift`
- **Actions:**
  - Update AppleWeatherKitAPI to use iOS 26 WeatherKit APIs
  - Add support for new weather data types
  - Update weather condition mappings

### 3.3 SwiftData Compatibility
- **File:** `hatti/hattiApp.swift`
- **Actions:**
  - Update SwiftData schema for iOS 26
  - Add iOS 26 specific model configurations
  - Update migration logic

## Phase 4: Architecture Improvements

### 4.1 MVVM Enhancements
- **Files:** All ViewModels
- **Actions:**
  - Standardize ViewModel initialization patterns
  - Improve error handling consistency
  - Add proper dependency injection

### 4.2 Service Layer Updates
- **Files:** All Service classes
- **Actions:**
  - Add proper protocol definitions
  - Improve actor isolation patterns
  - Standardize logging approach

## Phase 5: Testing and Validation

### 5.1 Unit Tests
- **Files:** `hattiTests/`
- **Actions:**
  - Update tests for iOS 26 APIs
  - Add tests for new features
  - Ensure test coverage for location integration

### 5.2 UI Tests
- **Files:** `hattiUITests/`
- **Actions:**
  - Update UI tests for iOS 26
  - Add tests for location permission flows
  - Test background update scenarios

## Phase 6: Finalization

### 6.1 Documentation
- **Files:** Documentation folder
- **Actions:**
  - Update architecture documentation
  - Add iOS 26 migration guide
  - Document new features

### 6.2 Cleanup
- **Actions:**
  - Remove deprecated code
  - Clean up commented-out code
  - Update build scripts

## Timeline Estimate
- **Phase 1:** 1-2 hours
- **Phase 2:** 3-4 hours
- **Phase 3:** 4-6 hours
- **Phase 4:** 2-3 hours
- **Phase 5:** 2-3 hours
- **Phase 6:** 1-2 hours
- **Total:** 13-20 hours

## Risk Assessment
- **High Risk:** Location services integration (complex permission flows)
- **Medium Risk:** Background task updates (timing and reliability)
- **Low Risk:** SwiftData updates (mostly configuration changes)

## Success Criteria
- ✅ App compiles and runs on iOS 26
- ✅ All incomplete features completed
- ✅ All tests passing
- ✅ No deprecated API warnings
- ✅ Proper error handling for all scenarios
- ✅ Clean, maintainable codebase