using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "SwordAnimData", menuName = "ScriptableObjects/SwordAnim", order = 1)]
public class SwordAnimData : ScriptableObject {

    public List<Vector3> targets = new List<Vector3>();
    public List<Vector3> originals = new List<Vector3>();
}
