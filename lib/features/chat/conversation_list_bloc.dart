import 'package:flutter_bloc/flutter_bloc.dart';

import 'chat_models.dart';
import 'chat_service.dart';

abstract class SupportTicketListEvent {}

class LoadSupportTickets extends SupportTicketListEvent {
  final SupportTicketStatus? status;
  final String? search;
  LoadSupportTickets({this.status, this.search});
}

abstract class SupportTicketListState {}

class SupportTicketListLoading extends SupportTicketListState {}

class SupportTicketListLoaded extends SupportTicketListState {
  final List<SupportTicket> tickets;
  final SupportTicketStatus? filterStatus;
  SupportTicketListLoaded(this.tickets, {this.filterStatus});
}

class SupportTicketListError extends SupportTicketListState {
  final String message;
  SupportTicketListError(this.message);
}

class SupportTicketListBloc extends Bloc<SupportTicketListEvent, SupportTicketListState> {
  final SupportService api;
  SupportTicketListBloc(this.api) : super(SupportTicketListLoading()) {
    on<LoadSupportTickets>((event, emit) async {
      emit(SupportTicketListLoading());
      try {
        final data = await api.listTickets(
          status: event.status,
          search: event.search,
        );
        emit(SupportTicketListLoaded(data, filterStatus: event.status));
      } catch (e) {
        emit(SupportTicketListError('Không thể tải danh sách yêu cầu: $e'));
      }
    });
  }
}
