import { Application } from "@hotwired/stimulus"

// Reuse the host app's Stimulus application if available, otherwise start a new one
const application = window.Stimulus || Application.start()

import SearchableSelectController from "controllers/admin_suite/searchable_select_controller"
application.register("admin-suite--searchable-select", SearchableSelectController)

import ToggleSwitchController from "controllers/admin_suite/toggle_switch_controller"
application.register("admin-suite--toggle-switch", ToggleSwitchController)

import TagSelectController from "controllers/admin_suite/tag_select_controller"
application.register("admin-suite--tag-select", TagSelectController)

import FileUploadController from "controllers/admin_suite/file_upload_controller"
application.register("admin-suite--file-upload", FileUploadController)

import MarkdownEditorController from "controllers/admin_suite/markdown_editor_controller"
application.register("admin-suite--markdown-editor", MarkdownEditorController)

import JsonEditorController from "controllers/admin_suite/json_editor_controller"
application.register("admin-suite--json-editor", JsonEditorController)

import CodeEditorController from "controllers/admin_suite/code_editor_controller"
application.register("admin-suite--code-editor", CodeEditorController)

import LiveFilterController from "controllers/admin_suite/live_filter_controller"
application.register("admin-suite--live-filter", LiveFilterController)

import ClickActionsController from "controllers/admin_suite/click_actions_controller"
application.register("admin-suite--click-actions", ClickActionsController)

import ClipboardController from "controllers/admin_suite/clipboard_controller"
application.register("admin-suite--clipboard", ClipboardController)

import SidebarController from "controllers/admin_suite/sidebar_controller"
application.register("admin-suite--sidebar", SidebarController)

import FlashController from "controllers/admin_suite/flash_controller"
application.register("admin-suite--flash", FlashController)

import DependentSearchableSelectController from "controllers/admin_suite/dependent_searchable_select_controller"
application.register("admin-suite--dependent-searchable-select", DependentSearchableSelectController)
