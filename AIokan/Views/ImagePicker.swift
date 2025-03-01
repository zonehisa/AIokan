//
//  ImagePicker.swift
//  AIokan
//
//  Created by 沖野匠吾 on 2025/02/28.
//

import SwiftUI

 // カメラまたはフォトライブラリを表示するビュー
 struct ImagePicker: UIViewControllerRepresentable {
     @Binding var image: UIImage? // 撮影、または選択した画像
     var sourceType: UIImagePickerController.SourceType
     @Environment(\.presentationMode) var presentationMode

     // フォトアルバムまたはカメラの画面の生成
     func makeUIViewController(context: Context) -> UIImagePickerController {
         let picker = UIImagePickerController() // 画面
         picker.sourceType = sourceType // この値が .camera ならカメラ画面、 .photoLibralyならフォトライブラリ画面を表示
         picker.delegate = context.coordinator // デリゲートをCoordinatorクラスに設定
         return picker
     }

     // 画面に更新があったとき
     func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

     // コーディネーターを自分(ImagePicker)に設定
     func makeCoordinator() -> Coordinator {
         Coordinator(self)
     }

     // コーディネータークラスを定義。
     // UIImagePickerControllerとUINavigationControllerの機能を使うために用意するクラス
     class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
         let parent: ImagePicker // 親オブジェクト(ImagePicker)を入れる変数

         init(_ parent: ImagePicker) {
             self.parent = parent
         }

         // 画像の選択が終了したときに呼ばれる関数
         func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
             if let image = info[.originalImage] as? UIImage {
                 parent.image = image
             }
             parent.presentationMode.wrappedValue.dismiss() // 1つ前の画面に戻る
         }

         // 画像の選択がキャンセルされたときに呼ばれる関数
         func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
             parent.presentationMode.wrappedValue.dismiss() // 1つ前の画面に戻る
         }
     }
 }
