//
//  ViewController.swift
//  ANMemo
//

import UIKit
import CoreData

/// 메모를 어떻게 편집했는지 구분하기 위한 값.
enum ANMemoEditorAction {
    case add, edit, cancel, delete, none
}

/// 메모 편집 후 액션에 따라 리스트를 처리하기 위한 함수를 정의하는 프로토콜
protocol ANMemoEditorDelegate: class {
    func memoEditor(_ editor: Any?, didFinishEditingWithAction action: ANMemoEditorAction)
}


/// 리스트 뷰 컨트롤러
class ANListViewController: UITableViewController, ANMemoEditorDelegate {
    
    let cellIdentifier: String = "memolistcell"

    lazy var context: NSManagedObjectContext = {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }()
    
    /// lazy 한 프로퍼티로, 처음 로딩 시 딱 한 번만 저장된 내용을 fetch 한다.
    
    lazy var memoList: Array<ANMemo> = { [unowned self] in
        let fetchRequest: NSFetchRequest<ANMemo> = ANMemo.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        do {
            let list = try self.context.fetch(fetchRequest)
            return list
        } catch {
            fatalError("can't fetch the memolist")
        }
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// 테이블 뷰가 셀을 자동으로 만들 수 있도록 기본 셀 타입을 등록한다.
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    }
    
    /// 테이블 뷰 데이터 소스
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return memoList.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        //
        let currentMemo = memoList[indexPath.row]
        cell.textLabel?.text = currentMemo.title
        return cell
    }
    
    
    /// segue에 따라 추가/편집 시 준비 작업을 나눈다.
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            super.prepare(for: segue, sender: sender)
            return
        }
        
        switch identifier {
            case "segueAdd": // 추가 시에는 새로운 메모
                let dest = segue.destination as! ANDetailViewController
                let newMemo = ANMemo(context: context)
                dest.memo = newMemo
                dest.action = .add
                dest.delegate = self
            case "segueEdit": // 편집 시에는 선택한 메모
                let dest = segue.destination as! ANDetailViewController
                let selectedMemo = memoList[tableView.indexPathForSelectedRow!.row]
                dest.memo = selectedMemo
                dest.action = .edit // 모드를 편집으로 바꿔준다.
                dest.delegate = self
            
            default:
                super.prepare(for: segue, sender: sender)
        }
    }
    
    /// 테이블 뷰에서 셀을 탭했을 때 편집 segue 실행
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "segueEdit", sender: nil)
    }
    
    
    // ANMemoEditorDelegate Conformance
    func memoEditor(_ editor: Any?, didFinishEditingWithAction action: ANMemoEditorAction) {
        
        // 추가, 편집, 삭제 시 데이터 변경 사항을 적용해준다.
        switch action {
        case .add:
            if let source = editor as? ANDetailViewController, let memo = source.memo {
                memoList.append(memo)
                tableView.insertRows(at: [IndexPath(row: memoList.count - 1, section:0)], with: .automatic)
            }
        case .delete:
            let d = tableView.indexPathForSelectedRow!.row
            let memoToDelete = memoList.remove(at: d)
            context.delete(memoToDelete)
            tableView.deleteRows(at: [IndexPath(row:d, section: 0)], with: .automatic)

        case .edit:
            if let source = editor as? ANDetailViewController, let memo = source.memo {
                let d = tableView.indexPathForSelectedRow!.row
                memoList.remove(at: d)
                memoList.insert(memo, at: d)
                tableView.reloadRows(at: [IndexPath(row:d, section: 0)], with: .right)
            }

        default:
            break
        }
        do {
            try context.save()
        } catch {
            fatalError("Fail to save data")
        }
    }

}

class ANDetailViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    
    var memo: ANMemo?
    var action: ANMemoEditorAction = .none
    weak var delegate: ANMemoEditorDelegate?
    
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var contentView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// 우측 상단에 완료 버튼을 추가한다.
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))]
        /// 만약 편집 모드라면 삭제 버튼도 추가한다.
        if case .edit = action {
            navigationItem.rightBarButtonItems?.append(UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(deleteTapped)))
        }
        /// 왼쪽 네비게이션 버튼은 back 이 아니라 취소로 변경한다.
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }
    
    /// 뷰가 표시되기 전에 메모의 내용으로 컨텐츠를 준비한다.
    override func viewWillAppear(_ animated: Bool) {
        if let memo = memo {
            titleField.text = memo.title
            contentView.text = memo.content
        }
    }
    
    /// 완료시 (추가 혹은 편집한 내용을 반영한다.)
    @IBAction func doneTapped() {
        memo?.date = Date() as NSDate
        memo?.title = titleField.text
        memo?.content = contentView.text
        delegate?.memoEditor(self, didFinishEditingWithAction: action)
        /// popViewController(animated:)가 UIViewController?를 리턴하기 때문에 경고를 없애기 위해
        /// _ = 추가
        _ = navigationController?.popViewController(animated: true)
    }
    
    /// 취소시
    @IBAction func cancelTapped() {
        delegate?.memoEditor(self, didFinishEditingWithAction: .cancel) // 목록에서 취소 동작 시 뭔가 액션을 취하고 싶다면...
        _ = navigationController?.popViewController(animated: true)
    }
    
    /// 제거시
    @IBAction func deleteTapped() {
        delegate?.memoEditor(self, didFinishEditingWithAction: .delete)
        _ = navigationController?.popViewController(animated: true)

    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.resignFirstResponder()
    }

}

