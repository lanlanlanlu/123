import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:record/data/repository/notes_repository.dart';
import 'package:drift/drift.dart';

// 事件
abstract class LocationListEvent extends Equatable {
  const LocationListEvent();
  
  @override
  List<Object?> get props => [];
}

class LocationListLoaded extends LocationListEvent {}

class LocationDeleted extends LocationListEvent {
  final String location;
  
  const LocationDeleted(this.location);
  
  @override
  List<Object?> get props => [location];
}

// 状态
abstract class LocationListState extends Equatable {
  const LocationListState();
  
  @override
  List<Object?> get props => [];
}

class LocationListLoading extends LocationListState {}

class LocationListLoadedState extends LocationListState {
  final List<String> locations;
  final bool isAfterDeletion;
  
  const LocationListLoadedState(this.locations, {this.isAfterDeletion = false});
  
  @override
  List<Object?> get props => [locations, isAfterDeletion];
}

class LocationListError extends LocationListState {
  final String message;
  
  const LocationListError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class LocationListBloc extends Bloc<LocationListEvent, LocationListState> {
  final NotesRepository _notesRepository;
  
  LocationListBloc({NotesRepository? notesRepository})
      : _notesRepository = notesRepository ?? NotesRepository(),
        super(LocationListLoading()) {
    on<LocationListLoaded>(_onLocationListLoaded);
    on<LocationDeleted>(_onLocationDeleted);
  }
  
  Future<void> _onLocationListLoaded(
    LocationListLoaded event,
    Emitter<LocationListState> emit,
  ) async {
    emit(LocationListLoading());
    
    try {
      // 获取所有位置信息
      final locations = await _notesRepository.getAllLocations();
      emit(LocationListLoadedState(locations));
    } catch (e) {
      emit(LocationListError('获取位置列表失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onLocationDeleted(
    LocationDeleted event,
    Emitter<LocationListState> emit,
  ) async {
    try {
      // 删除指定的位置标签
      await _notesRepository.deleteLocation(event.location);
      
      // 重新加载位置列表
      final locations = await _notesRepository.getAllLocations();
      emit(LocationListLoadedState(locations, isAfterDeletion: true));
    } catch (e) {
      emit(LocationListError('删除位置失败: ${e.toString()}'));
    }
  }
} 