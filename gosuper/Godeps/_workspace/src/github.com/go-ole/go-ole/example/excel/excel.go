// +build windows

package main

import (
	"time"

	ole "resin-supervisor/gosuper/Godeps/_workspace/src/github.com/go-ole/go-ole"
	"resin-supervisor/gosuper/Godeps/_workspace/src/github.com/go-ole/go-ole/oleutil"
)

func main() {
	ole.CoInitialize(0)
	unknown, _ := oleutil.CreateObject("Excel.Application")
	excel, _ := unknown.QueryInterface(ole.IID_IDispatch)
	oleutil.PutProperty(excel, "Visible", true)
	workbooks := oleutil.MustGetProperty(excel, "Workbooks").ToIDispatch()
	workbook := oleutil.MustCallMethod(workbooks, "Add", nil).ToIDispatch()
	worksheet := oleutil.MustGetProperty(workbook, "Worksheets", 1).ToIDispatch()
	cell := oleutil.MustGetProperty(worksheet, "Cells", 1, 1).ToIDispatch()
	oleutil.PutProperty(cell, "Value", 12345)

	time.Sleep(2000000000)

	oleutil.PutProperty(workbook, "Saved", true)
	oleutil.CallMethod(workbook, "Close", false)
	oleutil.CallMethod(excel, "Quit")
	excel.Release()

	ole.CoUninitialize()
}