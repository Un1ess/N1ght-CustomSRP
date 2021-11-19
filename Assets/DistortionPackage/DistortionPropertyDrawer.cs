using UnityEngine;
using UnityEditor;

[CustomPropertyDrawer(typeof(SoulVisualDistortion.SoulVisualDistortSettings))]
public class DistortionEditor : PropertyDrawer {
    
    private bool createdStyles = false;
    private GUIStyle boldLabel;

    private void CreateStyles() {
        createdStyles = true;
        boldLabel = GUI.skin.label;
        boldLabel.fontStyle = FontStyle.Bold;
    }

    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label) {
        //base.OnGUI(position, property, label);
        if (!createdStyles) CreateStyles();
        
		// Blit Settings
        EditorGUI.BeginProperty(position, label, property);
        EditorGUI.LabelField(position, "Blit Settings", boldLabel);
        SerializedProperty _event = property.FindPropertyRelative("Event");
        EditorGUILayout.PropertyField(_event);

		// "After Rendering Post Processing" Warning
        if (_event.intValue == (int)UnityEngine.Rendering.Universal.RenderPassEvent.AfterRenderingPostProcessing) {
            EditorGUILayout.HelpBox("The \"After Rendering Post Processing\" event does not work with Camera Color targets. " +
                "Unsure how to actually obtain the target after post processing has been applied. " +
                "Frame debugger seems to suggest a <no name> target?\n\n" +
                "Use the \"After Rendering\" event instead!", MessageType.Warning, true);
        }
        EditorGUILayout.PropertyField(property.FindPropertyRelative("blitMaterialPassIndex"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("blurRadius"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("blurIterationNum"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("scatterRadius"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("scatterIteration"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("directionalBlurIteration"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("directionalBlurRadius"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("directionalBlurAngle"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("heightMaskShader"));
        EditorGUILayout.PropertyField(property.FindPropertyRelative("distortionShader"));

        // Source
        // EditorGUILayout.Separator();
        // EditorGUILayout.LabelField("Source", boldLabel);
        // SerializedProperty srcType = property.FindPropertyRelative("srcType");
        // EditorGUILayout.PropertyField(srcType);
        // int enumValue = srcType.intValue;
        // if (enumValue == (int)SoulVisualDistortion.Target.TextureID) {
        //     EditorGUILayout.PropertyField(property.FindPropertyRelative("srcTextureId"));
        // } else if (enumValue == (int)SoulVisualDistortion.Target.RenderTextureObject) {
        //     EditorGUILayout.PropertyField(property.FindPropertyRelative("srcTextureObject"));
        // }

		// Destination
   //      EditorGUILayout.Separator();
   //      EditorGUILayout.LabelField("Destination", boldLabel);
   //      SerializedProperty dstType = property.FindPropertyRelative("dstType");
   //      EditorGUILayout.PropertyField(dstType);
   //      enumValue = dstType.intValue;
   //      if (enumValue == (int)SoulVisualDistortion.Target.TextureID) {
   //          EditorGUILayout.PropertyField(property.FindPropertyRelative("dstTextureId"));
			//
			// SerializedProperty overrideGraphicsFormat = property.FindPropertyRelative("overrideGraphicsFormat");
			// EditorGUILayout.BeginHorizontal();
			// EditorGUILayout.PropertyField(overrideGraphicsFormat);
			// if (overrideGraphicsFormat.boolValue){
   //          	EditorGUILayout.PropertyField(property.FindPropertyRelative("graphicsFormat"), GUIContent.none);
			// }
			// EditorGUILayout.EndHorizontal();
   //      } else if (enumValue == (int)SoulVisualDistortion.Target.RenderTextureObject) {
   //          EditorGUILayout.PropertyField(property.FindPropertyRelative("dstTextureObject"));
   //      }
        
        EditorGUI.indentLevel = 1;
        EditorGUI.EndProperty();
        property.serializedObject.ApplyModifiedProperties();
    }

}