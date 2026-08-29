/// Centring for the read-only result tables (DESIGN.md §12.5).
///
/// Material's `DataTable` offers two alignments and no third: a column is
/// start-aligned, or `numeric: true` and end-aligned. Centring is therefore not
/// a flag but a wrapper, and doing it by hand at forty call sites would leave
/// forty chances to forget one — so it lives here, and a table either uses
/// these two or visibly does not.
///
/// **Still only the read-only tables, but no longer for the original reason.**
/// This said the editable [DataGrid] keeps its right-aligned numerics, because
/// you type into those cells and a ragged left edge makes an outlier visible.
/// §8.3's drive overruled that on 2026-08-29 and the grid centres its values
/// too, so the whole app now agrees. What keeps this wrapper is Flutter rather
/// than the app: `DataTable` still offers start or end and no third option.
///
/// It works because `DataTable` sizes each column to its widest participant and
/// then lays every cell out at that width, so a `Center` inside one expands to
/// the column and centres within it. That is a fact about Flutter's internals
/// rather than about this app, so `centred_table_test.dart` holds it rather
/// than trusting it — and it earned that immediately: in a table of **one**
/// column the column is stretched to the full width, the heading does not
/// participate in the stretch the way a cell does, and the two stop agreeing.
/// Every table here has several columns, so the case does not arise; a fixture
/// written with one reports a centring no real table would show.
///
/// **Action columns are left alone.** The takt and workcenter schedules end in
/// a column of edit and delete buttons under a blank heading. Those are not
/// data being read down a column, and a stretched table would park them in the
/// middle of a wide empty cell, away from the row they act on.
library;

import 'package:flutter/material.dart';

/// A header cell whose text sits in the middle of its column.
///
/// Deliberately takes a `String` rather than a `Widget`: every header in the
/// app is a plain label, and the narrower type is what stops a caller quietly
/// reintroducing an uncentred one.
DataColumn centredColumn(String label) =>
    DataColumn(label: Center(child: Text(label)));

/// A body cell whose content sits in the middle of its column.
///
/// Takes a `Widget`, unlike [centredColumn], because a cell legitimately
/// carries more than text — a coloured float, a description capped and
/// ellipsised, a swatch beside a part number.
DataCell centredCell(Widget child) => DataCell(Center(child: child));

/// The common case: a cell that is only text.
DataCell centredText(String value, {TextStyle? style}) =>
    centredCell(Text(value, style: style));
