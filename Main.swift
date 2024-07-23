import UIKit
import SwiftUI
import PDFKit
import EventKit
import UniformTypeIdentifiers

// Make sure to import your PDFPreviewView file if it's in another module
// If it's in the same module, this is not needed

func extractTextFromPDF(from pdf: PDFDocument) -> String {
    var fullText = ""
    for pageIndex in 0..<pdf.pageCount {
        guard let page = pdf.page(at: pageIndex) else { continue }
        if let pageText = page.string {
            fullText.append(pageText)
        }
    }
    return fullText
}

func findDates(in text: String) -> [Date] {
    var dates: [Date] = []
    let datePattern = "\\b\\d{1,2}/\\d{1,2}/\\d{2,4}\\b"  // Example pattern for dates in format MM/DD/YYYY
    let regex = try! NSRegularExpression(pattern: datePattern, options: [])
    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy"
    
    for match in matches {
        if let range = Range(match.range, in: text) {
            let dateString = String(text[range])
            if let date = formatter.date(from: dateString) {
                dates.append(date)
            }
        }
    }
    return dates
}

func addEventsToCalendar(dates: [Date], title: String, completion: @escaping (Bool, Error?) -> Void) {
    let eventStore = EKEventStore()
    eventStore.requestWriteOnlyAccessToEvents { (granted, error) in
        guard granted else {
            completion(false, error)
            return
        }
        
        for date in dates {
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = date
            event.endDate = date.addingTimeInterval(3600) // 1 hour event
            event.calendar = eventStore.defaultCalendarForNewEvents
            do {
                try eventStore.save(event, span: .thisEvent)
            } catch {
                completion(false, error)
                return
            }
        }
        completion(true, nil)
    }
}

func processPDF(url: URL, title: String, completion: @escaping (Bool, Error?) -> Void) {
    guard let pdf = PDFDocument(url: url) else {
        completion(false, nil)
        return
    }
    let text = extractTextFromPDF(from: pdf)
    let dates = findDates(in: text)
    addEventsToCalendar(dates: dates, title: title, completion: completion)
}

class ViewController: UIViewController, UIDocumentPickerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let selectPDFButton = UIButton(type: .system)
        selectPDFButton.setTitle("Select PDF", for: .normal)
        selectPDFButton.addTarget(self, action: #selector(selectPDF), for: .touchUpInside)
        selectPDFButton.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        selectPDFButton.center = view.center
        view.addSubview(selectPDFButton)
    }
    
    @objc func selectPDF() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Display the selected PDF
        let pdfPreview = PDFPreviewView(url: url)
        let hostingController = UIHostingController(rootView: pdfPreview)
        present(hostingController, animated: true)
        
        // Process the PDF to extract dates and add to calendar
        processPDF(url: url, title: "Event Title") { success, error in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: success ? "Success" : "Error", message: success ? "Events added to calendar" : "Failed to add events to calendar: \(error?.localizedDescription ?? "Unknown error")", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}
