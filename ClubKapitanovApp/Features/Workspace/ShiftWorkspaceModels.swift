import Foundation

/// Namespace всех моделей Workspace-модуля.
///
/// Workspace крупнее остальных экранов, поэтому здесь собраны State, ViewModel и
/// вложенные display-модели. Interactor меняет `State`, Presenter строит `ViewModel`,
/// а UIKit views не читают domain-сущности напрямую.
enum ShiftWorkspace {
    struct State {
        /// Текущий рабочий state экрана. Он содержит исходную смену и локальные
        /// операции, которые UI может менять до закрытия смены.
        var shift: Shift
        let rentalTypes: [RentalType]
        let souvenirProducts: [SouvenirProduct]
        let fineTemplates: [FineTemplate]
        var rentalOrders: [RentalOrder]
        var souvenirSales: [SouvenirSale]
        var fines: [FineRecord]
        var selectedSection: ShiftWorkspaceSection
    }

    struct ParticipantViewModel {
        let id: UUID
        let name: String
        let joinedAtText: String
    }

    struct SectionItemViewModel {
        let section: ShiftWorkspaceSection
        let isSelected: Bool
    }

    struct ActionButtonViewModel {
        /// Модель кнопки добавления операции и модалки подтверждения.
        let index: Int
        let title: String
        let itemTitle: String
        let unitPrice: Money
        let confirmationTitle: String
        let confirmButtonTitle: String
    }

    struct RentalOrderItemTypeViewModel {
        let index: Int
        let title: String
        let tariffText: String
        let iconText: String
        let floatingNumbers: [Int]
    }

    struct RentalOrderItemInput {
        let rentalTypeIndex: Int
        let number: Int
    }

    struct ActiveRentalOrderViewModel {
        let id: UUID
        let title: String
        let itemsText: String
        let startedAtText: String
        let totalAmountText: String
        let startedAt: Date
        let expectedEndAt: Date
        let editableItems: [RentalOrderItemInput]
        let paymentMethod: PaymentMethod
        let editButtonTitle: String
        let extendButtonTitle: String
        let completeButtonTitle: String
    }

    enum OperationKind {
        /// Различает операции, у которых одинаковый UI изменения количества.
        case souvenir
        case fine
    }

    struct QuantityAdjustmentViewModel {
        /// Описывает, какой счетчик должен измениться после нажатия +/- в отчете.
        let kind: OperationKind
        let index: Int
    }

    struct ReportRowViewModel {
        let title: String
        let detail: String
        let amount: String
        let quantityAdjustment: QuantityAdjustmentViewModel?
    }

    struct ReportGroupViewModel {
        let title: String
        let emptyText: String
        let rows: [ReportRowViewModel]
        let footerText: String?

        init(
            title: String,
            emptyText: String,
            rows: [ReportRowViewModel],
            footerText: String? = nil
        ) {
            self.title = title
            self.emptyText = emptyText
            self.rows = rows
            self.footerText = footerText
        }
    }

    struct CloseShiftManualRowViewModel {
        let title: String
        let placeholder: String
    }

    struct CloseShiftModalViewModel {
        let totalsLines: [String]
        let reportDateText: String
        let weatherTitle: String
        let weatherPlaceholder: String
        let equipmentRows: [CloseShiftManualRowViewModel]
        let batteryRows: [CloseShiftManualRowViewModel]
        let dismissButtonTitle: String
        let confirmButtonTitle: String
    }

    enum ContentViewModel {
        /// Данные центральной области экрана. Каждый case соответствует выбранному
        /// разделу в сайдбаре и содержит только то, что нужно этому разделу.
        case ducks(
            intro: String,
            createOrderButtonTitle: String,
            rentalTypes: [RentalOrderItemTypeViewModel],
            activeOrders: [ActiveRentalOrderViewModel],
            summaryLines: [String],
            report: ReportGroupViewModel
        )
        case participants(
            intro: String,
            participants: [ParticipantViewModel],
            addButtonTitle: String
        )
        case souvenirs(
            intro: String,
            buttons: [ActionButtonViewModel],
            summaryLines: [String],
            report: ReportGroupViewModel
        )
        case fines(
            intro: String,
            buttons: [ActionButtonViewModel],
            summaryLines: [String],
            report: ReportGroupViewModel
        )
        case temporaryReport(
            intro: String,
            infoLines: [String],
            rentalReport: ReportGroupViewModel,
            summaryLines: [String],
            employeeLines: [String],
            souvenirReport: ReportGroupViewModel,
            fineReport: ReportGroupViewModel
        )
        case closeShift(
            intro: String,
            shiftLines: [String],
            buttonTitle: String
        )
    }

    struct ViewModel {
        let screenTitle: String
        let appTitle: String
        let pointName: String
        let openedAtText: String
        let participants: [ParticipantViewModel]
        let addParticipantButtonTitle: String
        let sections: [SectionItemViewModel]
        let content: ContentViewModel
        let closeShiftModal: CloseShiftModalViewModel
    }

    enum Load {
        struct Response {
            let state: State
        }
    }

    enum ActionFeedback {
        struct Response {
            let title: String
            let message: String
        }

        struct ViewModel {
            let title: String
            let message: String
        }
    }
}
