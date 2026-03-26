import UIKit
import UniformTypeIdentifiers
import JobApplicationShared

class ShareViewController: UIViewController {
    private var sharedURL: String = ""
    private var companyField: UITextField!
    private var titleField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        extractURL()
    }

    private func setupUI() {
        let navBar = UINavigationBar(frame: .zero)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        let navItem = UINavigationItem(title: "Save Job")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        navBar.items = [navItem]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        companyField = UITextField()
        companyField.placeholder = "Company"
        companyField.borderStyle = .roundedRect
        companyField.textContentType = .organizationName
        stack.addArrangedSubview(companyField)

        titleField = UITextField()
        titleField.placeholder = "Job Title"
        titleField.borderStyle = .roundedRect
        stack.addArrangedSubview(titleField)

        let urlLabel = UILabel()
        urlLabel.textColor = .secondaryLabel
        urlLabel.font = .preferredFont(forTextStyle: .caption1)
        urlLabel.numberOfLines = 2
        urlLabel.tag = 100
        stack.addArrangedSubview(urlLabel)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func extractURL() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                        DispatchQueue.main.async {
                            if let url = item as? URL {
                                self?.sharedURL = url.absoluteString
                                if let label = self?.view.viewWithTag(100) as? UILabel {
                                    label.text = url.absoluteString
                                }
                            }
                        }
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                        DispatchQueue.main.async {
                            if let text = item as? String, text.hasPrefix("http") {
                                self?.sharedURL = text
                                if let label = self?.view.viewWithTag(100) as? UILabel {
                                    label.text = text
                                }
                            }
                        }
                    }
                    return
                }
            }
        }
    }

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func saveTapped() {
        var job = JobApplication()
        job.company = companyField.text ?? ""
        job.title = titleField.text ?? ""
        job.url = sharedURL
        job.status = .wishlist

        // Load existing jobs, append, save
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.zsparks.JobApplicationWizard"
        )
        guard let dirURL = containerURL else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        let jobsURL = dirURL.appendingPathComponent("jobs.json")
        let coordinator = NSFileCoordinator()
        var error: NSError?

        coordinator.coordinate(writingItemAt: jobsURL, options: .forMerging, error: &error) { url in
            var jobs: [JobApplication] = []
            if let data = try? Data(contentsOf: url) {
                jobs = (try? JSONDecoder().decode([JobApplication].self, from: data)) ?? []
            }
            jobs.append(job)
            if let data = try? JSONEncoder().encode(jobs) {
                try? FileManager.default.createDirectory(
                    at: dirURL,
                    withIntermediateDirectories: true
                )
                try? data.write(to: url, options: .atomic)
            }
        }

        extensionContext?.completeRequest(returningItems: nil)
    }
}
