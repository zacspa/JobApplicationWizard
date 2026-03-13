import Foundation
import AppKit
import ComposableArchitecture

// MARK: - PDFClient

public struct PDFClient {
    public var printJobDescription: @Sendable (JobApplication) async -> Void
    public var generateAndSavePDF: @Sendable (JobApplication) async throws -> String  // returns saved path
    public var openPDF: @Sendable (String) async -> Void

    public init(
        printJobDescription: @escaping @Sendable (JobApplication) async -> Void,
        generateAndSavePDF: @escaping @Sendable (JobApplication) async throws -> String,
        openPDF: @escaping @Sendable (String) async -> Void
    ) {
        self.printJobDescription = printJobDescription
        self.generateAndSavePDF = generateAndSavePDF
        self.openPDF = openPDF
    }
}

extension PDFClient: DependencyKey {
    public static var liveValue: PDFClient {
        PDFClient(
            printJobDescription: { job in
                await MainActor.run {
                    let textView = buildTextView(for: job)
                    let printInfo = NSPrintInfo()
                    printInfo.topMargin = 36
                    printInfo.bottomMargin = 36
                    printInfo.leftMargin = 54
                    printInfo.rightMargin = 54
                    let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
                    printOp.showsPrintPanel = true
                    printOp.showsProgressPanel = true
                    printOp.run()
                }
            },
            generateAndSavePDF: { job in
                let pdfData: Data = await MainActor.run {
                    let textView = buildTextView(for: job)
                    return textView.dataWithPDF(inside: textView.bounds)
                }
                let appSupport = FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("JobApplicationWizard", isDirectory: true)
                let pdfsDir = appSupport.appendingPathComponent("pdfs", isDirectory: true)
                try FileManager.default.createDirectory(at: pdfsDir, withIntermediateDirectories: true)
                let pdfURL = pdfsDir.appendingPathComponent("\(job.id.uuidString).pdf")
                try pdfData.write(to: pdfURL, options: .atomicWrite)
                return pdfURL.path
            },
            openPDF: { path in
                await MainActor.run {
                    _ = NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
            }
        )
    }
}

@MainActor
private func buildTextView(for job: JobApplication) -> NSTextView {
    let attrStr = NSMutableAttributedString()

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 18),
        .foregroundColor: NSColor.labelColor
    ]
    let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13),
        .foregroundColor: NSColor.secondaryLabelColor
    ]
    let bodyAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.labelColor
    ]

    attrStr.append(NSAttributedString(string: "\(job.displayCompany)\n", attributes: titleAttrs))
    attrStr.append(NSAttributedString(string: "\(job.displayTitle)\n\n", attributes: subtitleAttrs))

    if !job.salary.isEmpty {
        attrStr.append(NSAttributedString(string: "Salary: \(job.salary)\n", attributes: subtitleAttrs))
    }
    if !job.url.isEmpty {
        attrStr.append(NSAttributedString(string: "URL: \(job.url)\n", attributes: subtitleAttrs))
    }
    if let applied = job.dateApplied {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        attrStr.append(NSAttributedString(string: "Applied: \(fmt.string(from: applied))\n", attributes: subtitleAttrs))
    }
    attrStr.append(NSAttributedString(string: "\n", attributes: bodyAttrs))
    attrStr.append(NSAttributedString(string: job.jobDescription, attributes: bodyAttrs))

    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 10000))
    textView.textStorage?.setAttributedString(attrStr)
    textView.isEditable = false

    // Force layout and size view to actual content height
    if let lm = textView.layoutManager, let tc = textView.textContainer {
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let inset = textView.textContainerInset
        let contentHeight = ceil(used.height + inset.height * 2)
        textView.setFrameSize(NSSize(width: 595, height: contentHeight))
    }

    return textView
}

extension PDFClient: TestDependencyKey {
    public static let testValue = PDFClient(
        printJobDescription: unimplemented("\(Self.self).printJobDescription", placeholder: ()),
        generateAndSavePDF: unimplemented("\(Self.self).generateAndSavePDF", placeholder: ""),
        openPDF: unimplemented("\(Self.self).openPDF", placeholder: ())
    )
}

extension DependencyValues {
    public var pdfClient: PDFClient {
        get { self[PDFClient.self] }
        set { self[PDFClient.self] = newValue }
    }
}
